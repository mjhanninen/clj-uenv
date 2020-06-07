#!/usr/bin/env bash

# ------------------------------------------------------------------------------
# Tests
# ------------------------------------------------------------------------------

test_01_load()
{
  eval_cljc <<EOF
(require '[uenv.core :as e])
(when (not-empty (e/load))
  (println "Did load"))
EOF
  expect <<EOF
Did load
EOF
}

test_02_undefined_envars()
{
  eval_cljc <<EOF
(require '[uenv.core :as e])
(let [env (e/load)]
  (prn :foo (e/get env "FOO"))
  (prn :bar (e/get env "BAR" "BAR with default")))
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
  eval_cljc <<EOF
(require '[uenv.core :as e])
(let [env (e/load)]
  (prn :foo (e/get env "FOO"))
  (prn :bar (e/get env "BAR" "BAR with default"))
  (prn :baz (e/get env "BAZ")))
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
  eval_cljc <<EOF
(require '[uenv.core :as e])
(let [env (e/load ["$f"])]
  (prn (e/get env "FOO" "FOO undefined")))
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
  eval_cljc <<EOF
(require '[uenv.core :as e])
(let [env (e/load ["$f"])]
  (prn (e/get env "FOO" "FOO is undefined"))
  (prn (e/get env "BAR" "BAR is undefined"))
  (prn (e/get env "BAZ" "BAZ is undefined")))
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
  eval_cljc <<EOF
(require '[uenv.core :as e])
(let [env (e/load ["$f1" "$f2"])]
  (prn (e/get env "FOO" "FOO is undefined"))
  (prn (e/get env "BAR" "BAR is undefined"))
  (prn (e/get env "BAZ" "BAZ is undefined"))
  (prn (e/get env "XYZZY" "XYZZY is undefined")))
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
  eval_cljc <<EOF
(require '[uenv.core :as e])
(let [env (e/load)]
  (prn :foo (e/get env "FOO" "FOO is undefined"))
  (prn :foo-file (e/get env "FOO_FILE" "FOO_FILE is undefined")))
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
  eval_cljc <<EOF
(require '[uenv.core :as e])
(let [env (e/load)]
  (prn (e/get env "FOO" "FOO is undefined")))
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
  eval_cljc <<EOF
(require '[uenv.core :as e])
(let [env (e/load ["$f_env"])]
  (prn :foo (e/get env "FOO" "FOO is undefined"))
  (prn :bar (e/get env "BAR" "BAR is undefined")))
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
  eval_cljc <<EOF
(require '[uenv.core :as e])
(let [env (e/load ["$f_env"])]
  (prn :foo (e/get env "FOO" "FOO is undefined"))
  (prn :bar (e/get env "BAR" "BAR is undefined")))
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
  eval_cljc <<EOF
(require '[uenv.core :as e])
(let [env (e/load)]
  (prn :foo (e/get env "FOO" "FOO is undefined"))
  (prn :foo-file (e/get env "FOO_FILE" "FOO_FILE is undefined")))
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
  eval_cljc <<EOF
(require '[uenv.core :as e])
(let [env (e/load ["$f_env"])]
  (prn :foo (e/get env "FOO" "FOO is undefined"))
  (prn :bar (e/get env "BAR" "BAR is undefined"))
  (prn :baz (e/get env "BAZ" "BAZ is undefined"))
  (prn :bar-file (e/get env "BAR_FILE" "BAR_FILE is undefined"))
  (prn :baz-file (e/get env "BAZ_FILE" "BAZ_FILE is undefined")))
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
NS_DIR=tmp/cljs
JS_DIR=tmp/js
OUT_REPORT="${OUT_DIR}/${TS_START}-report.txt"
PADSTR="................................................................................"
N_TESTS=0
N_ERRORS=0

run_test()
{
  ((N_TESTS++))
  TEST_NAME="$1 ($2)"
  TEST_FNAME_TRUNK="${OUT_DIR}/${TS_START}-${1}__${2}"
  test -e "$OUT_DIR" || mkdir -p "$OUT_DIR"
  OUT_ACTUAL="${TEST_FNAME_TRUNK}.actual"
  OUT_EXPECT="${TEST_FNAME_TRUNK}.expect"
  touch "$OUT_ACTUAL"
  touch "$OUT_EXPECT"
  echo -e -n "$TEST_NAME ${PADSTR:$((${#TEST_NAME} + 9))} \e[34mTESTING\e[39m"
  case "$2" in
    clj)
      EVAL_CLJC_COMMAND=eval_clj
      ;;
    clj8)
      EVAL_CLJC_COMMAND=eval_clj8
      ;;
    cljs)
      EVAL_CLJC_COMMAND=eval_cljs
      ;;
  esac
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

eval_cljc()
{
  "$EVAL_CLJC_COMMAND"
}

eval_clj()
{
  clojure -Srepro - >> "$OUT_ACTUAL" 2>&1
}

eval_clj8()
{
  clojure -Srepro -Aclj8 - >> "$OUT_ACTUAL" 2>&1
}

eval_cljs()
{
  clojure -Srepro -Acljs -m cljs.main -re node - >> "$OUT_ACTUAL" 2>&1
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
    run_test "$t" clj
    run_test "$t" clj8
    run_test "$t" cljs
  done
else
  for t in $(declare -F | sed -n -e 's/declare -f \(test_.*\)/\1/p')
  do
    run_test "$t" clj
    run_test "$t" clj8
    run_test "$t" cljs
  done
fi

report
