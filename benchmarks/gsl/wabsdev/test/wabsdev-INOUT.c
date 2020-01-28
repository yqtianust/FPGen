#include <stdio.h>
#include <stdlib.h>
#include <gsl/gsl_statistics.h>
#include <assert.h>
#include <float.h>

extern "C" {
#include <quadmath.h>
}

#ifndef N
#define N 32
#endif

#define K N/2

#ifndef FB
#define FB 64
#endif

#if(FB==64)
#define FT double
#elif(FB==80)
#define FT long double
#endif

int
main(int argc, char *argv[])
{
  assert(argc == 3);

  int i;
  char *inname = argv[1];
  char *outname = argv[2];
  FILE *infile = fopen(inname, "r");
  FILE *outfile = fopen(outname, "w");

  FT data[K], w[K];
  FT wabsdev;

  // read input data 
  float input[N]; i=0;
  for (i = 0 ; i < N ; i++) {
    __float128 in_data;
    fread(&in_data, sizeof(__float128), 1, infile);
    input[i]=(float)in_data;
  }
  fclose(infile);

  for (i = 0; i < K; i++){
    w[i]=input[i] /FLT_MAX * 100;	
  }

  for (i = 0 ; i <K; i++){
    data[i] = input[i+K] /FLT_MAX * 100;
  }

  // library call
  #if(FB==64)
    wabsdev     = gsl_stats_wabsdev(w, 1, data, 1, K);
  #elif(FB==80)
    wabsdev     = gsl_stats_long_double_wabsdev(w, 1, data, 1, K);
  #else
    exit(-1);
  #endif

  //printf ("The sample variance is %g\n", variance);

  __float128 out_data;
  out_data = (__float128) wabsdev;
  fwrite(&out_data, sizeof(__float128), 1, outfile);
  fclose(outfile);

  return 0;
}
