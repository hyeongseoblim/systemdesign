-- Socket 내부 심층 검수. 기존 ID와 질문 유지.
UPDATE cards
SET content_md = $socket_review$## 1. 대기열을 같은 Backlog로 뭉뚱그리지 않는다

Linux TCP의 listen(backlog)는 연결 수립을 마치고 accept를 기다리는 대기열의 크기와 관련된다. 연결 수립 중인 요청의 관리, 커널 상한, 애플리케이션의 처리 대기열은 별도다. backlog 값은 somaxconn 등의 환경 설정도 확인해야 하며 숫자 하나를 키워도 처리 용량 자체가 늘지는 않는다.

```mermaid
flowchart LR
    C[연결 요청] --> H[연결 수립 진행]
    H --> A[Accept 대기]
    A --> S[Accept한 연결]
    S --> Q[프로토콜과 업무 대기열]
    Q --> W[업무 처리]
```

**첫 질문 답변 예시:** “Backlog 외에 accept를 호출하는 스레드가 실행되는지, FD 제한과 메모리, CPU와 Event Loop 지연을 확인하겠습니다. 연결이 수립되지 않는 단계와 accept 이후 TLS·업무 처리가 막힌 단계를 구분하겠습니다.”

| 증거 | 확인할 계층 |
|---|---|
| 연결 수립 지연·재전송 | 네트워크·방화벽·수립 대기 상태 |
| accept 오류 EMFILE/ENFILE | 프로세스/시스템 FD 자원 |
| 수립된 연결이 accept를 기다림 | accept 처리율·CPU·Loop 지연 |
| 연결은 됐지만 응답 없음 | TLS·프레임 읽기·업무 큐·하류 |

Linux에서 accept한 Socket이 Listener의 O_NONBLOCK 설정을 자동 상속한다고 가정하지 않는다. accept4의 SOCK_NONBLOCK 등으로 새 연결의 동작을 명확히 정한다. 준비 알림 뒤에도 accept가 EAGAIN을 반환할 수 있으므로 반환값으로 분기한다.

## 2. send 성공은 어느 단계의 성공인가

일반적인 Stream Socket의 send는 반환한 바이트 수만큼 로컬에서 송신을 받아들였다는 뜻이다. 전체 버퍼보다 적은 길이를 반환할 수 있고, Non-blocking이면 EAGAIN/EWOULDBLOCK으로 지금 더 진행할 수 없음을 알릴 수 있다. 실제 코드에서는 EINTR과 연결 오류도 처리한다.

```mermaid
flowchart LR
    A[애플리케이션 출력] --> S[로컬 송신 상태]
    S --> N[TCP 전달]
    N --> R[상대 수신 버퍼]
    R --> P[상대 프로토콜 처리]
    P --> B[업무 커밋과 응답]
```

가상 10KB 응답에서 3KB만 수락됐다면 남은 7KB와 위치를 기록한다. 다음 쓰기에 처음부터 10KB를 다시 주면 앞부분이 중복된다. 전송할 데이터가 없을 때 계속 쓰기 가능 알림을 처리하는 바쁜 루프도 피한다.

TCP ACK는 상대 TCP 계층의 확인이지 상대 애플리케이션의 업무 커밋 확인이 아니다. 업무 성공을 알아야 한다면 프로토콜 응답과 요청 식별자가 필요하다. 응답이 유실된 경우 성공·실패를 단정하지 않고 같은 업무 키 재시도나 상태 조회로 처리한다. Socket 수준 재전송과 업무 명령 재실행은 다른 층이다.

## 3. Buffer를 늘리기 전에 소비 속도를 본다

상대가 읽지 않으면 수신 여유가 줄고 송신 측도 결국 진행이 제한될 수 있다. 그런데 애플리케이션이 무제한 사용자 공간 큐를 두면 이 제한을 메모리 증가로 숨기게 된다.

| 계층 | 관리할 것 | 무작정 늘릴 때의 비용 |
|---|---|---|
| Accept 대기 | 유입·accept 처리·자원 | 연결 대기 증가 |
| Socket 송수신 Buffer | 전달과 소비 속도 | 연결별 메모리와 큐 지연 |
| 애플리케이션 출력 큐 | 바이트 상한·생산 제한 | 느린 고객이 메모리 독점 |
| 업무 Worker 큐 | 작업 수·기한·거절 | 이미 무의미한 요청이 계속 쌓임 |

요청 기한, 큐 상한, 읽기/생산 중단과 재개 조건을 함께 정한다. 예를 들어 가상의 연결 10,000개에 각 1MiB 출력이 쌓이면 출력 데이터만 약 9.77GiB다. 이것은 서버 처리량 측정이 아니라 메모리 예산 계산이며 객체·커널 버퍼 비용은 추가된다.

## 4. Half-close는 한 방향의 종료다

shutdown(SHUT_WR)은 더 보내지 않겠다는 방향 종료다. 이미 보낸 바이트 뒤에 Stream의 끝이 전달되고 상대는 남은 데이터를 읽은 뒤 EOF를 관측할 수 있다. 반대 방향의 응답은 계속 받을 수 있다. close는 FD 해제와 관련되므로 양방향 프로토콜 상태와 구분한다.

TCP는 바이트 스트림이다. recv 한 번이 요청 한 개에 대응하지 않는다. 길이·구분자·상위 프로토콜 규칙으로 프레임을 조립해야 한다. EOF를 요청 종료로 사용하는 프로토콜도 있지만, HTTP Keep-alive처럼 연결을 재사용하는 프로토콜에 같은 규칙을 적용할 수 없다. TLS에는 TLS 계층의 종료 규약도 있다.

> **구현 함정**
>
> RST를 정상 요청 종료로 처리하지 않는다. 오류 시 이미 상대 업무가 일부 또는 전부 실행됐는지는 Socket 오류만으로 알 수 없다. 반대로 EOF를 받자마자 연결 상태를 버리면 아직 보내야 할 응답을 잃을 수 있다.

## 5. Loopback에서 Half-close를 확인한다

다음 예제는 로컬 TCP에서 EOF로 요청을 끝내는 **가상 프로토콜**이다. 클라이언트가 쓰기를 종료한 뒤에도 서버 응답을 읽는 것을 확인한다. 운영 서버의 접속 폭주·패킷 손실·TLS를 재현하지 않는다.

```python
import socket

def receive_to_eof(sock):
    chunks = []
    while True:
        chunk = sock.recv(1024)
        if not chunk:
            return b"".join(chunks)
        chunks.append(chunk)

with socket.socket() as listener, socket.socket() as client:
    listener.settimeout(2)
    client.settimeout(2)
    listener.bind(("127.0.0.1", 0))
    listener.listen(1)
    client.connect(listener.getsockname())
    connection, _ = listener.accept()
    with connection as server:
        server.settimeout(2)
        client.sendall(b"PING")
        client.shutdown(socket.SHUT_WR)
        assert receive_to_eof(server) == b"PING"
        server.sendall(b"PONG")
        server.shutdown(socket.SHUT_WR)
        assert receive_to_eof(client) == b"PONG"
```

recv가 나눠 반환해도 누적하며, timeout으로 시험이 무한히 대기하지 않게 한다. 예제는 메시지 크기가 작고 한 요청만 처리한다. 실서비스에서 EOF까지 무제한 메모리에 모으지 말고 길이 상한과 전체 처리 기한을 적용한다.

## 6. 면접에서 구분할 성공 기준

연결 성공, accept 성공, send의 부분 진행, 상대 EOF, 업무 응답을 따로 기록한다. 지연이 어느 대기열에서 발생하는지 추적하고, 재시도 정책은 결과 불명과 중복 업무를 고려한다. backlog·Buffer·Worker 수를 늘리는 처방보다 병목과 예산을 먼저 설명한다.

## 참고 자료

- [Linux listen(2)](https://man7.org/linux/man-pages/man2/listen.2.html)
- [Linux accept(2)](https://man7.org/linux/man-pages/man2/accept.2.html)
- [Linux send(2)](https://man7.org/linux/man-pages/man2/send.2.html)
- [Linux shutdown(2)](https://man7.org/linux/man-pages/man2/shutdown.2.html)
- [Linux recv(2)](https://man7.org/linux/man-pages/man2/recv.2.html)$socket_review$
WHERE slug = 'cs-08-socket-internals' AND source = 'MANUAL';
