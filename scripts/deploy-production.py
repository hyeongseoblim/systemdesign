#!/usr/bin/env python3
"""Dispatch production API deployment, wait for its result, then verify production."""
import json
import os
import sys
import time
import urllib.error
import urllib.request
import uuid

API = 'https://api.github.com/repos/hyeongseoblim/systemdesign'
WEB = 'https://jobstudy-eta.vercel.app'
SERVICE = 'https://jobstudy-api-55363157288.asia-northeast3.run.app'


def request(url, data=None, github=False):
    headers = {'User-Agent': 'jobstudy-deployment', 'Accept': 'application/vnd.github+json'}
    if github:
        token = os.environ.get('GH_TOKEN')
        if not token:
            raise RuntimeError('GH_TOKEN is missing; configure it securely in environment network secrets')
        headers['Authorization'] = 'Bearer ' + token
        headers['X-GitHub-Api-Version'] = '2022-11-28'
    body = None if data is None else json.dumps(data).encode()
    if body is not None:
        headers['Content-Type'] = 'application/json'
    with urllib.request.urlopen(urllib.request.Request(url, data=body, headers=headers), timeout=60) as response:
        content = response.read()
        return json.loads(content) if content and github else content


def main():
    request_id = str(uuid.uuid4())
    # Check read authorization before dispatching a paid production build.
    workflow = request(API + '/actions/workflows/deploy-api.yml', github=True)
    if workflow['state'] != 'active':
        raise RuntimeError('Deployment workflow is not active')
    request(API + '/actions/workflows/deploy-api.yml/dispatches',
            {'ref': 'main', 'inputs': {'request_id': request_id}}, github=True)
    print('Deployment dispatched:', request_id, flush=True)
    deadline = time.monotonic() + 2400
    run = None
    while time.monotonic() < deadline:
        runs = request(API + '/actions/workflows/deploy-api.yml/runs?event=workflow_dispatch&per_page=50', github=True)['workflow_runs']
        run = next((r for r in runs if r.get('display_title') == 'Deploy API ' + request_id), None)
        if run:
            print(run['html_url'], run['status'], run.get('conclusion'), flush=True)
            if run['status'] == 'completed':
                break
        time.sleep(15)
    else:
        raise RuntimeError('Timed out waiting; inspect GitHub Actions before retrying (run may still be active)')
    if run['conclusion'] != 'success':
        raise RuntimeError('Deployment did not succeed: ' + run['html_url'])
    health = json.loads(request(SERVICE + '/api/v1/health'))
    cards = json.loads(request(SERVICE + '/api/v1/cards?limit=1'))
    if health.get('status') != 'UP' or not cards.get('items'):
        raise RuntimeError('Production health/card verification failed')
    detail = json.loads(request(SERVICE + '/api/v1/cards/' + cards['items'][0]['id']))
    if not detail.get('contentMd') or not detail.get('questions'):
        raise RuntimeError('Production card detail verification failed')
    page = request(WEB + '/')
    if b'<html' not in page.lower():
        raise RuntimeError('Production web did not return HTML')
    print('API deployment, production cards and web response verified:', run['html_url'])
    print('Vercel release/version parity is not verified by this web response check.')


if __name__ == '__main__':
    try:
        main()
    except (RuntimeError, urllib.error.URLError, ValueError, KeyError) as error:
        print('Deployment incomplete:', error, file=sys.stderr)
        sys.exit(1)
