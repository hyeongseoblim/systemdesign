#!/usr/bin/env bash
# Oracle A1.Flex(ARM) 무료 인스턴스를 "Out of capacity"가 풀릴 때까지 자동 재시도 생성.
# 본인 PC에서 실행 (OCI CLI 설치 + `oci setup config` 인증 선행 필요).
#
# 사용:
#   1) 아래 변수 5개를 채운다
#   2) bash oci-retry-launch.sh
#   3) 켜두면 capacity 풀리는 순간 자동으로 인스턴스를 만들고 멈춘다
set -uo pipefail

# ─────────── 채워야 할 값 (얻는 법은 파일 하단 주석 참고) ───────────
COMPARTMENT_ID=""   # 보통 tenancy(루트) OCID:  ocid1.tenancy.oc1..xxxx
SUBNET_ID=""        # 만든 public subnet OCID:  ocid1.subnet.oc1..xxxx
IMAGE_ID=""         # Ubuntu 22.04 aarch64 OCID: ocid1.image.oc1..xxxx
SSH_KEY_FILE="$HOME/.ssh/oracle.pub"   # 본인 SSH public key 경로
DISPLAY_NAME="jobstudy"

# ─────────── 인스턴스 사양 (무료 한도 내) ───────────
SHAPE="VM.Standard.A1.Flex"
OCPUS=1
MEMORY_GB=6
BOOT_VOLUME_GB=47
RETRY_INTERVAL=60   # 재시도 간격(초). 너무 짧으면 throttle 주의

# ─────────── 검증 ───────────
for v in COMPARTMENT_ID SUBNET_ID IMAGE_ID; do
  if [ -z "${!v}" ]; then echo "❌ $v 가 비었습니다. 스크립트 상단을 채우세요."; exit 1; fi
done
if [ ! -f "$SSH_KEY_FILE" ]; then echo "❌ SSH public key 없음: $SSH_KEY_FILE"; exit 1; fi

# AD 자동 조회 (Tokyo는 단일 AD)
AD=$(oci iam availability-domain list --compartment-id "$COMPARTMENT_ID" \
      --query 'data[0].name' --raw-output 2>/dev/null)
if [ -z "$AD" ]; then echo "❌ AD 조회 실패. OCI CLI 인증/권한 확인."; exit 1; fi
echo "▶ Availability Domain: $AD"
echo "▶ ${OCPUS} OCPU / ${MEMORY_GB}GB / boot ${BOOT_VOLUME_GB}GB — ${RETRY_INTERVAL}s 간격 재시도 시작"

attempt=0
while true; do
  attempt=$((attempt + 1))
  printf "[%s] 시도 #%d ... " "$(date +%H:%M:%S)" "$attempt"
  OUT=$(oci compute instance launch \
    --compartment-id "$COMPARTMENT_ID" \
    --availability-domain "$AD" \
    --shape "$SHAPE" \
    --shape-config "{\"ocpus\": $OCPUS, \"memoryInGBs\": $MEMORY_GB}" \
    --image-id "$IMAGE_ID" \
    --subnet-id "$SUBNET_ID" \
    --assign-public-ip true \
    --boot-volume-size-in-gbs "$BOOT_VOLUME_GB" \
    --display-name "$DISPLAY_NAME" \
    --ssh-authorized-keys-file "$SSH_KEY_FILE" \
    2>&1)

  if echo "$OUT" | grep -q '"id"'; then
    echo "✅ 생성 성공!"
    echo "$OUT" | grep -m1 '"id"'
    echo "→ 콘솔에서 Public IP 확인 후 SSH 접속하세요."
    break
  elif echo "$OUT" | grep -qiE "out of (host )?capacity|capacity"; then
    echo "capacity 부족, ${RETRY_INTERVAL}s 후 재시도"
  else
    echo "다른 오류:"
    echo "$OUT" | head -4
    echo "→ 설정 문제일 수 있으니 확인 권장. ${RETRY_INTERVAL}s 후 재시도"
  fi
  sleep "$RETRY_INTERVAL"
done

# ─────────────────────────────────────────────────────────────
# 값 얻는 법:
#
# [OCI CLI 설치]
#   bash -c "$(curl -L https://raw.githubusercontent.com/oracle/oci-cli/master/scripts/install/install.sh)"
#   oci setup config        # tenancy OCID, user OCID, region(ap-tokyo-1), API key 생성
#   → 생성된 public key를 콘솔: Profile → User settings → API keys → Add 에 등록
#
# [COMPARTMENT_ID]  보통 tenancy OCID. 콘솔 Profile → Tenancy 에서 복사.
#
# [SUBNET_ID]       콘솔 Networking → VCN → 해당 public subnet → OCID 복사.
#
# [IMAGE_ID]        아래 명령으로 Ubuntu 22.04 ARM 이미지 OCID 조회:
#   oci compute image list --compartment-id "$COMPARTMENT_ID" \
#     --operating-system "Canonical Ubuntu" --operating-system-version "22.04" \
#     --shape "VM.Standard.A1.Flex" --query 'data[0].id' --raw-output
#
# [SSH_KEY_FILE]    없으면 생성: ssh-keygen -t ed25519 -f ~/.ssh/oracle
#                   → ~/.ssh/oracle.pub 를 사용, ~/.ssh/oracle 로 SSH 접속.
# ─────────────────────────────────────────────────────────────
