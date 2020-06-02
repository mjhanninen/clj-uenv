#!/usr/bin/env bash

# ------------------------------------------------------------------------------
# Tests
# ------------------------------------------------------------------------------

test_01_load()
{
  eval_clj <<EOF
(require '[minienv :as m])
(when (not-empty (m/load))
  (println "Did load"))
EOF
  expect <<EOF
Did load
EOF
}

test_02_undefined_envars()
{
  eval_clj <<EOF
(require '[minienv :as m])
(let [env (m/load)]
  (prn :foo (m/get env "FOO"))
  (prn :bar (m/get env "BAR" "BAR with default")))
EOF
  expect <<EOF
:foo nil
:bar "BAR with default"
EOF
}

test_03_vars_from_env()
{
  FOO="FOO in environment" \
  BAR="BAR in environment" \
  eval_clj <<EOF
(require '[minienv :as m])
(let [env (m/load)]
  (prn :foo (m/get env "FOO"))
  (prn :bar (m/get env "BAR" "BAR with default"))
  (prn :baz (m/get env "BAZ")))
EOF
  expect <<EOF
:foo "FOO in environment"
:bar "BAR in environment"
:baz nil
EOF
}

test_04_empty_dotenv_file()
{
  local f="$(mktemp)"
  touch "$f"
  eval_clj <<EOF
(require '[minienv :as m])
(let [env (m/load ["$f"])]
  (prn (m/get env "FOO" "FOO undefined")))
EOF
  expect <<EOF
"FOO undefined"
EOF
}

test_05_non_empty_dotenv_file()
{
  local f="$(mktemp)"
  cat <<EOF > "$f"
# This is a .env file

FOO=FOO in file
BAR=BAR in file
EOF
  BAR="BAR in environment" \
  eval_clj <<EOF
(require '[minienv :as m])
(let [env (m/load ["$f"])]
  (prn (m/get env "FOO" "FOO is undefined"))
  (prn (m/get env "BAR" "BAR is undefined"))
  (prn (m/get env "BAZ" "BAZ is undefined")))
EOF
  expect <<EOF
"FOO in file"
"BAR in environment"
"BAZ is undefined"
EOF
}

test_06_shadowing()
{
  local f1="$(mktemp)"
  local f2="$(mktemp)"
  cat <<EOF > "$f1"
# This .env file comes first and is overridden by the latter
FOO=FOO in file 1
BAR=BAR in file 1
EOF
  cat <<EOF > "$f2"
# This .env file comes second and overrides the former
BAR=BAR in file 2
BAZ=BAZ in file 2
EOF
  BAZ="BAZ in environment" \
  eval_clj <<EOF
(require '[minienv :as m])
(let [env (m/load ["$f1" "$f2"])]
  (prn (m/get env "FOO" "FOO is undefined"))
  (prn (m/get env "BAR" "BAR is undefined"))
  (prn (m/get env "BAZ" "BAZ is undefined"))
  (prn (m/get env "XYZZY" "XYZZY is undefined")))
EOF
  expect <<EOF
"FOO in file 1"
"BAR in file 2"
"BAZ in environment"
"XYZZY is undefined"
EOF
}

test_07_value_from_file()
{
  local f_val="$(mktemp)"
  echo -n "Value for FOO from file" > "$f_val"
  FOO_FILE="$f_val" \
  eval_clj <<EOF
(require '[minienv :as m])
(let [env (m/load)]
  (prn :foo (m/get env "FOO" "FOO is undefined"))
  (prn :foo-file (m/get env "FOO_FILE" "FOO_FILE is undefined")))
EOF
  expect <<EOF
:foo "Value for FOO from file"
:foo-file "$f_val"
EOF
}

test_08_multiline_value_from_file()
{
  local f_val="$(mktemp)"
  cat <<EOF > "$f_val"
First line
Second line
EOF
  FOO_FILE="$f_val" \
  eval_clj <<EOF
(require '[minienv :as m])
(let [env (m/load)]
  (prn (m/get env "FOO" "FOO is undefined")))
EOF
  expect <<EOF
"First line\nSecond line\n"
EOF
}

test_09_latter_file_value_shadows_former_env_value()
{
  local f_val="$(mktemp)"
  local f_env="$(mktemp)"
  echo -n "Value for FOO from value file" > "$f_val"
  cat <<EOF > "$f_env"
FOO=FOO in .env file
BAR=BAR in .env file
EOF
  FOO_FILE="$f_val" \
  eval_clj <<EOF
(require '[minienv :as m])
(let [env (m/load ["$f_env"])]
  (prn :foo (m/get env "FOO" "FOO is undefined"))
  (prn :bar (m/get env "BAR" "BAR is undefined")))
EOF
  expect <<EOF
:foo "Value for FOO from value file"
:bar "BAR in .env file"
EOF
}

test_0A_latter_env_value_shadows_former_file_value()
{
  local f_val="$(mktemp)"
  local f_env="$(mktemp)"
  echo -n "Value for FOO and BAR from value file" > "$f_val"
  cat <<EOF > "$f_env"
FOO_FILE=$f_val
BAR_FILE=$f_val
EOF
  FOO="FOO in environment" \
  eval_clj <<EOF
(require '[minienv :as m])
(let [env (m/load ["$f_env"])]
  (prn :foo (m/get env "FOO" "FOO is undefined"))
  (prn :bar (m/get env "BAR" "BAR is undefined")))
EOF
  expect <<EOF
:foo "FOO in environment"
:bar "Value for FOO and BAR from value file"
EOF
}

test_0B_env_value_trumps_file_value_in_environment()
{
  local f_val="$(mktemp)"
  echo -n "Value for FOO from value file" > "$f_val"
  FOO_FILE="$f_val" \
  FOO="FOO in environment" \
  eval_clj <<EOF
(require '[minienv :as m])
(let [env (m/load)]
  (prn :foo (m/get env "FOO" "FOO is undefined"))
  (prn :foo-file (m/get env "FOO_FILE" "FOO_FILE is undefined")))
EOF
  expect <<EOF
:foo "FOO in environment"
:foo-file "$f_val"
EOF
}

test_0C_latter_definition_trumps_earlier_in_env_file()
{
  local f_env="$(mktemp)"
  local f_bar_val="$(mktemp)"
  local f_baz_val="$(mktemp)"
  echo -n "BAR redefined through value file" > "$f_bar_val"
  echo -n "BAZ first defined through value file" > "$f_baz_val"
  cat <<EOF > "$f_env"
FOO=1st definition of FOO
BAR=BAR first defined in .env file
BAZ_FILE=$f_baz_val
FOO=2nd definition of FOO
BAR_FILE=$f_bar_val
BAZ=BAZ redefined in .env file
EOF
  eval_clj <<EOF
(require '[minienv :as m])
(let [env (m/load ["$f_env"])]
  (prn :foo (m/get env "FOO" "FOO is undefined"))
  (prn :bar (m/get env "BAR" "BAR is undefined"))
  (prn :baz (m/get env "BAZ" "BAZ is undefined"))
  (prn :bar-file (m/get env "BAR_FILE" "BAR_FILE is undefined"))
  (prn :baz-file (m/get env "BAZ_FILE" "BAZ_FILE is undefined")))
EOF
  expect <<EOF
:foo "2nd definition of FOO"
:bar "BAR redefined through value file"
:baz "BAZ redefined in .env file"
:bar-file "$f_bar_val"
:baz-file "$f_baz_val"
EOF
}

# ------------------------------------------------------------------------------
# Test runner
# ------------------------------------------------------------------------------

cd "$(dirname "${BASH_SOURCE[0]}")/.."

TS_START="$(date +%Y%m%d%H%M%S)"
OUT_DIR=tmp/log
OUT_REPORT="${OUT_DIR}/${TS_START}-report.txt"
PADSTR="................................................................................"
N_TESTS=0
N_ERRORS=0

run_test()
{
  TEST_NAME="$1"
  ((N_TESTS++))
  test -e "$OUT_DIR" || mkdir -p "$OUT_DIR"
  OUT_ACTUAL="${OUT_DIR}/${TS_START}-${TEST_NAME}.actual"
  OUT_EXPECT="${OUT_DIR}/${TS_START}-${TEST_NAME}.expect"
  touch "$OUT_ACTUAL"
  touch "$OUT_EXPECT"
  echo -e -n "$TEST_NAME ${PADSTR:$((${#TEST_NAME} + 9))} \e[34mTESTING\e[39m"
  "$1" || true
  if diff -q "$OUT_EXPECT" "$OUT_ACTUAL" >/dev/null
  then
    echo -e "\e[8D\e[K..... \e[32mOK\e[39m"
    echo "$TEST_NAME ${PADSTR:$((${#TEST_NAME} + 4))} OK" >> "$OUT_REPORT"
  else
    ((N_ERRORS++))
    echo -e "\e[8D\e[K... \e[31mFAIL\e[39m"
    echo '-- DIFF STARTS -----------------------------------------------------------------'
    diff -u --color=auto \
         "$OUT_EXPECT" --label "$OUT_EXPECT" \
         "$OUT_ACTUAL" --label "$OUT_ACTUAL"
    echo '-- DIFF ENDS -------------------------------------------------------------------'
    echo "$TEST_NAME ${PADSTR:$((${#TEST_NAME} + 6))} FAIL" >> "$OUT_REPORT"
    echo '-- DIFF STARTS -----------------------------------------------------------------' >> "$OUT_REPORT"
    diff -u --color=never \
         "$OUT_EXPECT" --label "$OUT_EXPECT" \
         "$OUT_ACTUAL" --label "$OUT_ACTUAL" \
         >> "$OUT_REPORT"
    echo '-- DIFF ENDS -------------------------------------------------------------------' >> "$OUT_REPORT"
  fi
}

eval_clj()
{
  clojure -Srepro - >> "$OUT_ACTUAL" 2>&1
}

expect()
{
  cat - >> "$OUT_EXPECT"
}

report()
{
  cat <<EOF

Total tests: $N_TESTS
  Successes: $((N_TESTS - N_ERRORS))
   Failures: $N_ERRORS
EOF
  cat <<EOF >> "$OUT_REPORT"

Total tests: $N_TESTS
  Successes: $((N_TESTS - N_ERRORS))
   Failures: $N_ERRORS
EOF
  if (( N_ERRORS == 0 ))
  then
    echo "    Outcome: SUCCESS" >> "$OUT_REPORT"
    echo -e "    Outcome: \e[32mSUCCESS\e[39m"
    exit 0
  else
    echo -e "    Outcome: FAILURE" >> "$OUT_REPORT"
    echo -e "    Outcome: \e[31mFAILURE\e[39m"
    exit 1
  fi
}

if (( $# > 0 ))
then
  for t in "$@"
  do
    run_test "$t"
  done
else
  for t in $(declare -F | sed -n -e 's/declare -f \(test_.*\)/\1/p')
  do
    run_test "$t"
  done
fi

report
