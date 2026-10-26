// Executed in the generation browser. Preserve sequence events while laying out
// messages, notes and control scopes as a narrow vertical reading diagram.
export function sequenceSvg(actors, messages, types, title) {
  const escape = text => String(text).replace(/[&<>\"]/g, c => ({ '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;' }[c]));
  const clean = value => {
    const text = String(value ?? '').replace(/<br\s*\/?\s*>/gi, '\n').replace(/(?<!&)#(\d+);/g, '&#$1;').replace(/ﬂ°°/g, '&#').replace(/ﬂ°/g, '&').replace(/¶ß/g, ';');
    const decoder = document.createElement('textarea'); decoder.innerHTML = text;
    return decoder.value;
  };
  const context = document.createElement('canvas').getContext('2d');
  function lines(text, maxWidth, size = 16) {
    context.font = `${size}px Arial, sans-serif`;
    const result = [];
    for (const paragraph of clean(text).split('\n')) {
      let line = '';
      for (const char of paragraph) {
        if (line && context.measureText(line + char).width > maxWidth) { result.push(line); line = ''; }
        line += char;
      }
      result.push(line);
    }
    return result;
  }
  function label(id) {
    if (Array.isArray(id)) return id.map(label).join(' · ');
    return clean(actors.find(([key]) => key === id)?.[1]?.description ?? id ?? '');
  }
  let y = 16, number = 0;
  const parts = [], stack = [];
  function row(heading, body, kind = 'message', depth = stack.length) {
    const x = 14 + Math.min(depth, 3) * 8, width = 286 - x;
    const head = lines(heading, width - 28, 14), text = body ? lines(body, width - 28) : [];
    const height = 22 + head.length * 21 + (text.length ? 9 + text.length * 24 : 0);
    const fill = kind === 'note' ? '#fff8e6' : kind === 'scope' ? '#eef3f0' : '#ffffff';
    parts.push(`<rect x="${x}" y="${y}" width="${width}" height="${height}" rx="8" fill="${fill}" stroke="#bdc8c0"/>`);
    head.forEach((line, i) => parts.push(`<text x="${x + 14}" y="${y + 23 + i * 21}" font-size="14" font-weight="600" fill="#3c5a46">${escape(line)}</text>`));
    text.forEach((line, i) => parts.push(`<text x="${x + 14}" y="${y + 23 + head.length * 21 + 9 + i * 24}" font-size="16" fill="#20242b">${escape(line)}</text>`));
    y += height + 18;
  }
  row(title || '메시지 흐름', '위에서 아래로 요청·응답과 조건 분기를 따라 읽습니다.', 'scope', 0);
  for (const [id, actor] of actors) row('참여자', (actor.box?.name ? clean(actor.box.name) + ' · ' : '') + label(id), 'scope', 0);
  const starts = new Map([[types.LOOP_START, 'loop'], [types.ALT_START, 'alt'], [types.OPT_START, 'opt'], [types.PAR_START, 'par'], [types.PAR_OVER_START, 'par'], [types.CRITICAL_START, 'critical'], [types.BREAK_START, 'break'], [types.RECT_START, '구간']]);
  const ends = new Set([types.LOOP_END, types.ALT_END, types.OPT_END, types.PAR_END, types.CRITICAL_END, types.BREAK_END, types.RECT_END]);
  const branches = new Map([[types.ALT_ELSE, 'else'], [types.PAR_AND, 'and · 병렬 경로'], [types.CRITICAL_OPTION, 'option']]);
  const dotted = new Set([types.DOTTED, types.DOTTED_CROSS, types.DOTTED_OPEN, types.DOTTED_POINT, types.BIDIRECTIONAL_DOTTED]);
  for (const message of messages) {
    const type = message.type;
    const text = typeof message.message === 'string' ? clean(message.message) : '';
    if (type === types.AUTONUMBER) continue; // Each visible message receives a step number below.
    if (starts.has(type)) {
      const scope = starts.get(type); row(`${scope} 시작`, text, 'scope'); stack.push(scope);
    } else if (ends.has(type)) {
      const scope = stack.pop() || '구간'; row(`${scope} 종료`, text, 'scope');
    } else if (branches.has(type)) {
      row(branches.get(type), text, 'scope', Math.max(0, stack.length - 1));
    } else if (type === types.NOTE) {
      row(`설명 · ${[label(message.from), label(message.to)].filter((x, i, a) => x && a.indexOf(x) === i).join(' · ')}`, text, 'note');
    } else if (type === types.ACTIVE_START || type === types.ACTIVE_END) {
      row(type === types.ACTIVE_START ? '활성화' : '활성화 종료', label(message.from || message.to), 'scope');
    } else {
      const arrow = [types.BIDIRECTIONAL_SOLID, types.BIDIRECTIONAL_DOTTED].includes(type) ? ' ↔ ' : dotted.has(type) ? ' ⇢ ' : ' → ';
      row(`${++number}. ${label(message.from)}${arrow}${label(message.to)}`, text);
    }
  }
  if (stack.length) throw new Error('Unclosed sequence control scope');
  return `<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 300 ${y}" width="300" height="${y}" role="img"><title>${escape(title || '세로 메시지 흐름')}</title><g font-family="Arial, sans-serif">${parts.join('')}</g></svg>`;
}
