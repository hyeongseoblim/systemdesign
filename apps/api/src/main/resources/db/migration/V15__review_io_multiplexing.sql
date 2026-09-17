-- I/O 다중화 심층 검수. 기존 ID와 질문 유지.
UPDATE cards
SET content_md = $io_review$## 1. 호출의 대기와 여러 연결의 대기를 구분한다

Non-blocking Socket은 지금 진행할 수 없는 read/write에서 스레드를 기다리게 하는 대신 EAGAIN 또는 EWOULDBLOCK을 반환할 수 있다. Multiplexing은 여러 FD의 준비 상태를 함께 기다리는 수단이다. 둘을 조합하면 연결마다 바쁜 반복 확인을 하지 않아도 된다.

준비 알림은 요청 처리 완료가 아니다. 다른 실행 흐름이 데이터를 먼저 소비할 수도 있으므로 알림 뒤의 실제 I/O 결과를 확인한다. epoll이 CPU 계산이나 동기 DNS 호출을 자동 비동기로 바꿔주는 것도 아니다.

```mermaid
flowchart LR
    S[Socket과 Pipe] --> K[관심 목록과 준비 목록]
    K --> E[이벤트 수집]
    E --> R[제한된 I/O 처리]
    R --> Q[연결별 상태와 대기 작업]
    Q --> E
```

| 방식 | 관심 대상 관리 | 확인할 비용 |
|---|---|---|
| select | 호출마다 FD 집합을 준비하고 반환 집합 확인 | 최대 FD와 집합 순회, glibc FD_SETSIZE 제한 |
| poll | 호출마다 FD 배열과 결과 확인 | 배열 전달·순회 |
| epoll | 등록 목록을 유지하고 준비 이벤트 수집 | 등록 변경·준비 이벤트 수·사용자 Handler |

Linux glibc의 select fd_set은 통상 FD_SETSIZE 1024 제한이 있다. 열린 연결 수뿐 아니라 FD 번호가 범위 안인지도 중요하다. epoll을 “서버 전체가 항상 O(1)”이라고 설명하지 않는다. 준비된 연결이 많으면 처리할 이벤트와 데이터도 많다.

## 2. LT와 ET의 핵심은 언제 다시 기다려도 되는가다

LT는 준비 상태가 남아 있으면 이후 대기에서도 알려줄 수 있다. ET는 상태 변화 기반 알림이므로 데이터를 일부만 읽고 다음 알림을 기다리면 남은 데이터가 정체될 수 있다. 일반적인 ET 구성은 Non-blocking FD를 사용하고 EAGAIN까지 진행한 후 새 알림을 기다린다.

동시에 한 연결을 끝없이 처리하면 다른 연결이 굶을 수 있다. 가상 서버에서 매번 읽을 데이터가 계속 들어오는 고객 A와 작은 요청 하나를 보낸 고객 B를 생각하자. A 처리만 지속하면 B의 준비 이벤트를 이미 받았어도 응답하지 못한다. 바이트·시간 예산으로 양보할 때는 아직 처리 가능한 연결을 애플리케이션 Ready Queue에 남겨 이어 처리한다. ET에서 읽기를 덜 끝낸 채 새 Edge만 기다리는 설계와 구분한다.

EPOLLONESHOT을 사용하면 이벤트를 받은 뒤 명시적으로 재활성화하는 책임이 생긴다. 여러 Worker가 연결 하나를 처리할 때 상태 소유권도 별도로 정한다.

## 3. 읽기 결과를 다섯 가지로 나눈다

다음은 **Non-blocking Stream Socket의 읽기 분기**를 보여주는 C 예제다. consume은 짧은 처리이며 실제 서비스에는 프레임 조립·메모리 상한·공정성 예산을 추가한다.

```c
#include <unistd.h>
#include <errno.h>

/* 반환: 0=지금 더 읽을 수 없음, 1=peer EOF, -1=오류 */
int drain_stream(int fd, void (*consume)(const char *, ssize_t)) {
    char buf[4096];
    for (;;) {
        ssize_t n = read(fd, buf, sizeof(buf));
        if (n > 0) {
            consume(buf, n);
            continue;
        }
        if (n == 0) return 1;
        if (errno == EINTR) continue;
        if (errno == EAGAIN || errno == EWOULDBLOCK) return 0;
        return -1;
    }
}
```

양수 반환은 읽은 바이트 수이며 버퍼가 덜 찼다고 요청 한 개가 끝난 것은 아니다. Stream은 메시지 경계를 보장하지 않는다. 고정 길이·길이 헤더·구분자 같은 프로토콜 프레이밍이 필요하다.

0은 여기서 Peer의 쓰기 종료를 의미한다. 남은 응답을 보낼 필요가 있으면 곧바로 연결 객체를 폐기하지 않는다. Datagram의 길이 0 메시지와 같은 의미로 해석해서도 안 된다. EINTR은 데이터 반환 전 신호로 중단된 경우 재시도하고, EAGAIN은 지금의 읽기 중단점이다. 실제 오류는 연결 상태에 맞게 처리한다.

> **구현 함정**
>
> EOF를 기록하지 않으면 닫힌 연결을 계속 감시하는 바쁜 루프가 생길 수 있다. 반대로 연결을 닫은 뒤 같은 FD 번호가 재사용될 수 있으므로 늦게 도착한 작업이 새 연결 상태를 수정하지 않게 연결 식별자와 수명을 관리한다.

## 4. 쓰기도 부분 진행과 역압력이 필요하다

가상 응답이 10KB인데 Socket이 3KB만 수락했다면 나머지 7KB와 전송 위치를 연결 상태에 보관한다. EAGAIN에서 중단하고 쓰기 가능 상태에서 남은 구간부터 이어간다. 처음부터 재전송하면 응답 바이트가 중복될 수 있다. 실제 구현은 신호·오류·연결 종료도 처리해야 한다.

LT에서 보낼 데이터가 없는데도 쓰기 가능 알림을 계속 감시하면 불필요한 Wakeup이 반복될 수 있다. 연결의 출력 대기 상태에 맞춰 관심 이벤트를 관리한다. 쓰기 성공은 커널이 데이터를 받아들였다는 뜻이지 상대 애플리케이션이 업무를 완료했다는 확인이 아니다.

느린 수신자가 있는 동안 무제한 응답을 쌓으면 Non-blocking 코드도 메모리를 고갈시킨다. 출력 큐 상한·상류 생산 제한·읽기 일시 중단·기한과 연결 종료 정책을 정한다. 읽기를 재개할 때 ET의 준비 상태를 놓치지 않는지도 확인한다.

## 5. Event Loop와 Worker 사이도 제한한다

CPU 작업이나 Blocking I/O를 Worker Pool로 옮겨도 무제한 작업 큐는 지연을 숨길 뿐이다. 작업 수·큐 길이·취소·결과 전달을 제한하고, 완료 결과는 연결의 유효성과 순서를 확인한 뒤 반영한다. Loop 스레드에서 Future 결과를 기다리면 분리한 효과가 사라진다.

| 지표 | 구분할 원인 |
|---|---|
| Loop 지연·Handler 실행 시간 | CPU 독점·Blocking 호출·공정성 |
| 읽기/쓰기 큐 길이 | 수신 속도·생산량·역압력 |
| Worker 대기 시간 | Pool 용량·긴 작업·큐 상한 |
| 연결별 처리량과 p99 | 일부 연결의 독점과 느린 Consumer |

면접에서는 Non-blocking과 준비 알림의 역할, LT/ET 중단점, EOF·부분 진행, 사용자 코드의 실행 예산을 함께 설명한다. 이 문서의 C 분기는 전체 epoll 서버 구현이 아니며 Linux 부하 시험 결과로 간주하지 않는다.

## 참고 자료

- [Linux epoll(7)](https://man7.org/linux/man-pages/man7/epoll.7.html)
- [Linux read(2)](https://man7.org/linux/man-pages/man2/read.2.html)
- [Linux select(2)](https://man7.org/linux/man-pages/man2/select.2.html)$io_review$
WHERE slug = 'cs-07-io-multiplexing' AND source = 'MANUAL';
