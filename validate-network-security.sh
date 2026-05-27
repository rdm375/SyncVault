#!/usr/bin/env bash
set -euo pipefail

FAIL=0

pass() {
  echo "PASS: $*"
}

warn() {
  echo "WARN: $*"
}

fail() {
  echo "FAIL: $*"
  FAIL=1
}

section() {
  echo
  echo "== $* =="
}

require_cmd() {
  command -v "$1" >/dev/null 2>&1 || fail "Missing command: $1"
}

section "Basic command availability"

for cmd in sshd ufw fail2ban-client ss systemctl awk grep sed; do
  require_cmd "$cmd"
done

section "SSH effective configuration"

SSHD_CONFIG="$(sshd -T 2>/dev/null || true)"

check_sshd_value() {
  local key="$1"
  local expected="$2"
  local actual

  actual="$(printf '%s\n' "$SSHD_CONFIG" | awk -v k="$key" '$1 == k {print $2; exit}')"

  if [[ -z "$actual" ]]; then
    fail "sshd option '$key' not found"
  elif [[ "$actual" == "$expected" ]]; then
    pass "sshd $key = $actual"
  else
    fail "sshd $key = $actual, expected $expected"
  fi
}

check_sshd_value "permitrootlogin" "no"
check_sshd_value "passwordauthentication" "no"
check_sshd_value "pubkeyauthentication" "yes"
check_sshd_value "kbdinteractiveauthentication" "no"
check_sshd_value "challengeresponseauthentication" "no"
check_sshd_value "x11forwarding" "no"

MAX_AUTH_TRIES="$(printf '%s\n' "$SSHD_CONFIG" | awk '$1 == "maxauthtries" {print $2; exit}')"
if [[ -n "$MAX_AUTH_TRIES" && "$MAX_AUTH_TRIES" -le 3 ]]; then
  pass "sshd maxauthtries = $MAX_AUTH_TRIES"
else
  warn "sshd maxauthtries = ${MAX_AUTH_TRIES:-unset}; recommended <= 3"
fi

section "SSH service state"

if systemctl is-active --quiet ssh; then
  pass "ssh service is active"
else
  fail "ssh service is not active"
fi

if systemctl is-enabled --quiet ssh; then
  pass "ssh service is enabled"
else
  fail "ssh service is not enabled"
fi

section "SSH listeners"

SSH_LISTENERS="$(ss -tlnp | grep -E 'sshd|:22 ' || true)"

if [[ -n "$SSH_LISTENERS" ]]; then
  echo "$SSH_LISTENERS"
  pass "sshd is listening"
else
  fail "sshd does not appear to be listening"
fi

section "UFW status"

if ufw status | grep -q "Status: active"; then
  pass "UFW is active"
else
  fail "UFW is not active"
fi

UFW_VERBOSE="$(ufw status verbose || true)"
echo "$UFW_VERBOSE"

if printf '%s\n' "$UFW_VERBOSE" | grep -qi "Default: deny (incoming)"; then
  pass "UFW default incoming policy is deny"
else
  fail "UFW default incoming policy is not deny"
fi

if printf '%s\n' "$UFW_VERBOSE" | grep -qi "allow (outgoing)"; then
  pass "UFW default outgoing policy is allow"
else
  warn "UFW default outgoing policy is not clearly allow"
fi

for rule in "22/tcp" "22000/tcp" "22000/udp" "21027/udp"; do
  if ufw status numbered | grep -q "$rule"; then
    pass "UFW allows $rule"
  else
    fail "UFW missing expected rule: $rule"
  fi
done

section "Fail2ban service and sshd jail"

if systemctl is-active --quiet fail2ban; then
  pass "fail2ban service is active"
else
  fail "fail2ban service is not active"
fi

if systemctl is-enabled --quiet fail2ban; then
  pass "fail2ban service is enabled"
else
  fail "fail2ban service is not enabled"
fi

if fail2ban-client status | grep -q "sshd"; then
  pass "fail2ban sshd jail exists"
else
  fail "fail2ban sshd jail not found"
fi

if fail2ban-client status sshd >/dev/null 2>&1; then
  pass "fail2ban sshd jail is queryable"
  fail2ban-client status sshd
else
  fail "fail2ban sshd jail is not queryable"
fi

section "Syncthing GUI exposure"

SYNCTHING_8384="$(ss -tlnp | grep ':8384' || true)"

if [[ -z "$SYNCTHING_8384" ]]; then
  warn "No Syncthing GUI listener found on 8384"
else
  echo "$SYNCTHING_8384"

  if printf '%s\n' "$SYNCTHING_8384" | grep -q "127.0.0.1:8384"; then
    pass "Syncthing GUI is bound to localhost IPv4"
  else
    fail "Syncthing GUI may not be bound to localhost IPv4"
  fi

  if printf '%s\n' "$SYNCTHING_8384" | grep -q "0.0.0.0:8384"; then
    fail "Syncthing GUI is exposed on all IPv4 interfaces"
  fi

  if printf '%s\n' "$SYNCTHING_8384" | grep -q "\[::\]:8384"; then
    fail "Syncthing GUI is exposed on all IPv6 interfaces"
  fi
fi

section "Unexpected listening TCP ports"

echo "Listening TCP ports:"
ss -tlnp

EXPECTED_TCP_REGEX=':(22|8384|22000)\b'
UNEXPECTED_TCP="$(ss -H -tlnp | awk '{print $4}' | grep -E ':[0-9]+$' | grep -Ev "$EXPECTED_TCP_REGEX" || true)"

if [[ -z "$UNEXPECTED_TCP" ]]; then
  pass "No unexpected TCP listening ports detected"
else
  warn "Unexpected TCP listening addresses/ports detected:"
  echo "$UNEXPECTED_TCP"
fi

section "Unexpected listening UDP ports"

echo "Listening UDP ports:"
ss -ulnp

EXPECTED_UDP_REGEX=':(68|22000|21027|5353|5355)\b'
UNEXPECTED_UDP="$(ss -H -ulnp | awk '{print $4}' | grep -E ':[0-9]+$' | grep -Ev "$EXPECTED_UDP_REGEX" || true)"

if [[ -z "$UNEXPECTED_UDP" ]]; then
  pass "No unexpected UDP listening ports detected"
else
  warn "Unexpected UDP listening addresses/ports detected:"
  echo "$UNEXPECTED_UDP"
fi

section "Summary"

if [[ "$FAIL" -eq 0 ]]; then
  echo "NETWORK SECURITY VALIDATION PASSED"
  exit 0
else
  echo "NETWORK SECURITY VALIDATION FAILED"
  exit 1
fi
