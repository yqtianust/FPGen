#!/bin/bash
benchPath=/home/fptesting/FPTesting/benchmarks/matrix
klee=/home/fptesting/klee-float
S3FP_DIR=/home/fptesting/s3fp-v0.1
export LD_LIBRARY_PATH=${S3FP_DIR}:${LD_LIBRARY_PATH}
Meschach=/home/fptesting/FPTesting/benchmarks/matrix/meschach
Meschach64=/home/fptesting/FPTesting/benchmarks/matrix/meschach
Meschach128=/home/fptesting/FPTesting/benchmarks/matrix/meschach-ld

FLOG=$benchPath/result-baselines.txt

NN=8
TIMEBUDGET=7200

run_baselines()
{
  test=$1
  N=$2  
 
  ## run random and s3fp
  cd $benchPath/$test; rm-rf s3fp; mkdir s3fp; cd s3fp; pwd
  cp ../$test-INOUT.c .
  
  ## random
  echo -e "\nStart RANDOM:"
  gsl=${GSL_PATH}-inout
  cd $benchPath/$test/s3fp; rm -rf sequential-*
  gcc -o sequential-64 -DFT=double -DN=$N -I${Meschach64} $test-INOUT.c ${Meschach64}/meschach.a -lm 
  gcc -o sequential-80 -DFT=__float128 -DN=$N -I${Meschach128} $test-INOUT.c ${Meschach128}/meschach.a -lm
  echo TIMEOUT = $TIMEBUDGET > s3fp_setting
  echo RESOURCE = TIME >> s3fp_setting
  echo RSEED = 0 >> s3fp_setting
  echo FTERROR = REL >> s3fp_setting
  echo REL_DELTA = 1.175494351e-38F >> s3fp_setting
  echo UNIFORM_INPUT = true >> s3fp_setting
  echo UNIFORM_INPUTLB = -100.0 >> s3fp_setting
  echo UNIFORM_INPUTUB = 100.0  >> s3fp_setting
  echo RT = URT >> s3fp_setting
  echo PARALLELRT = false >> s3fp_setting
  echo "==== run random ====" 
  ${S3FP_DIR}/s3fp 32 $N test_input ./sequential-64 test_output_64 ./sequential-80 test_output_80 &> urt-out
  mv best_input urt_input
  rerr=`cat urt-out | grep "Best Relative Error" | cut -d " " -f 4 | awk '{printf "%5.4e", $1}'`
  rsecs=`cat urt-out | grep "TIMEOUT" | cut -d " " -f 2`
  rtime=`date -u -d @${rsecs} +"%T"`
  rnum=`cat urt-out | grep "N PLAIN TESTS" | cut -d ":" -f 2 | sed "s/^ *//"`
  cat urt-out	
  echo -e "\n  -RANDOM      Rel. Error: $rerr, #Inputs: $rnum, time: $rtime" 
  echo "  -RANDOM      Rel. Error: $rerr, #Inputs: $rnum, time: $rtime" >> $FLOG
  cd $benchPath

  ## s3fp
  echo -e "\nStart S3FP:"
  gsl=${GSL_PATH}-inout
  cd $benchPath/$test/s3fp; rm -rf sequential-*
  gcc -o sequential-64 -DFT=double -DN=$N -I${Meschach64} $test-INOUT.c ${Meschach64}/meschach.a -lm 
  gcc -o sequential-80 -DFT=__float128 -DN=$N -I${Meschach128} $test-INOUT.c ${Meschach128}/meschach.a -lm
  echo TIMEOUT = $TIMEBUDGET > s3fp_setting
  echo RESOURCE = TIME >> s3fp_setting
  echo RSEED = 0 >> s3fp_setting
  echo FTERROR = REL >> s3fp_setting
  echo REL_DELTA = 1.175494351e-38F >> s3fp_setting
  echo UNIFORM_INPUT = true >> s3fp_setting
  echo UNIFORM_INPUTLB = -100.0 >> s3fp_setting
  echo UNIFORM_INPUTUB = 100.0  >> s3fp_setting
  echo RT = BGRT >> s3fp_setting
  echo PARALLELRT = false >> s3fp_setting
  echo "==== run s3fp ====" 
  ${S3FP_DIR}/s3fp 32 $N test_input ./sequential-64 test_output_64 ./sequential-80 test_output_80 &> bgrt-out	
  mv best_input bgrt_input
  serr=`cat bgrt-out | grep "Best Relative Error" | cut -d " " -f 4 | awk '{printf "%5.4e", $1}'`
  ssecs=`cat bgrt-out | grep "TIMEOUT" | cut -d " " -f 2`
  stime=`date -u -d @${ssecs} +"%T"`
  snum=`cat bgrt-out | grep "N BGRT TESTS" | cut -d ":" -f 2 | sed "s/^ *//"`
  cat bgrt-out
  echo -e "\n  -S3FP        Rel. Error: $serr, #Inputs: $snum, time: $stime" 
  echo "  -S3FP        Rel. Error: $serr, #Inputs: $snum, time: $stime" >> $FLOG 
  cd $benchPath

  ## run klee
  echo -e "\nStart KLEE-FLOAT:"
  klee=/home/fptesting/klee-float
  gsl=${GSL_PATH}-klee
  rm -rf $benchPath/$test/klee; mkdir $benchPath/$test/klee; cd $benchPath/$test/klee; pwd
  cp ../$test-SYMBOLIC.c .
  cd ../test; rm -rf sequential-*
  gcc -o sequential-64 -DFT=double -DN=$N -I${Meschach64} $test-INOUT.c ${Meschach64}/meschach.a -lm 
  gcc -o sequential-80 -DFT=__float128 -DN=$N -I${Meschach128} $test-INOUT.c ${Meschach128}/meschach.a -lm
  cd $benchPath/$test/klee

  clang-3.4 -DN=$N -I$klee/include -I$Meschach -emit-llvm -c -g $test-SYMBOLIC.c -o $test-tmp.bc
  llvm-link-3.4 $test-tmp.bc $Meschach/meschach.a.bc -o $test-tmp-1.bc
  mv $test-tmp-1.bc $test-tmp.bc
  llvm-link-3.4 $test-tmp.bc $benchPath/../../utils/injections.bc -o $test-SYMBOLIC.bc
  rm $test-tmp.bc

  echo "time klee --allow-external-sym-calls --max-solver-time=$TIMEBUDGET --max-time=$TIMEBUDGET --search=nurs:covnew $test-SYMBOLIC.bc"
  time klee -allow-external-sym-calls --max-solver-time=$TIMEBUDGET --max-time=$TIMEBUDGET --search=nurs:covnew $test-SYMBOLIC.bc
 
  $benchPath/../../scripts/show_tests.sh &>/dev/null
  $benchPath/../../scripts/compute_error.sh "klee-last/test*-input" ../test/sequential-64 ../test/sequential-80

  kerr=`sort -k 3 -g -r rel-errors | head -n 1 | cut -d " " -f 3 | awk '{printf "%5.4e", $1}'`
  knum=`cat klee-last/info | grep "generated tests" | cut -d "=" -f 2 | sed "s/ *//"`
  ktime=`cat klee-last/info | grep "Elapsed" | cut -d " " -f 2`

  echo -e "\n  -KLEE-FLOAT  Rel. Error: $kerr, #Inputs: $knum, time: $ktime" 
  echo "  -KLEE-FLOAT  Rel. Error: $kerr, #Inputs: $knum, time: $ktime" >> $FLOG 
  cd $benchPath

}

tests="sum 1norm 2norm dot conv mv mm lu qr"

if [ $# -gt 0 ]; then
  tests=$@
fi

#rm -rf $FLOG; touch $FLOG
for test in $tests; do
  echo "Test $test"

  echo "Test $test:" >> $FLOG
  run_baselines $test $NN >$benchPath/$test-baselines.out 2>/dev/null
done
