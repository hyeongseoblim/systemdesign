"""Exercise the card's C read branches using injected read results, not Linux epoll."""
from pathlib import Path
import re
import subprocess
import tempfile

root = Path(__file__).resolve().parents[1]
raw = (root / 'apps/api/src/main/resources/content/cs-07-io-multiplexing.md').read_text()
example = re.search(r'```c\n(.*?)```', raw, re.S).group(1)
harness = r'''
#include <assert.h>
#include <string.h>
static int results[4], index_, size_, bytes;
ssize_t fake_read(int fd, void *buf, size_t len) {
    (void)fd;
    assert(index_ < size_);
    int n = results[index_++];
    if (n < 0) { errno = -n; return -1; }
    assert((size_t)n <= len);
    memset(buf, 'x', (size_t)n);
    return n;
}
static void consume(const char *buf, ssize_t n) {
    assert(n > 0 && buf[0] == 'x');
    bytes += (int)n;
}
static void scenario(int a, int b, int c, int count, int expected, int total) {
    results[0]=a; results[1]=b; results[2]=c;
    index_=0; size_=count; bytes=0;
    assert(drain_stream(1, consume) == expected);
    assert(index_ == count && bytes == total);
}
int main(void) {
    scenario(-EINTR, 2, -EAGAIN, 3, 0, 2);
    scenario(2, 3, 0, 3, 1, 5);
    scenario(-EWOULDBLOCK, 0, 0, 1, 0, 0);
    scenario(-EIO, 0, 0, 1, -1, 0);
    return 0;
}
'''
with tempfile.TemporaryDirectory(prefix='jobstudy-io-') as directory:
    source = Path(directory) / 'read.c'
    binary = Path(directory) / 'read-test'
    source.write_text('#define read fake_read\n' + example + harness)
    subprocess.run(['cc', '-std=c11', '-Wall', '-Wextra', '-Werror', str(source), '-o', str(binary)], check=True)
    subprocess.run([str(binary)], check=True, timeout=5)
print('C read branches passed: EINTR, partial data, EAGAIN/EWOULDBLOCK, EOF, error')
