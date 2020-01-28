#include <stdio.h>
#include <gsl/gsl_statistics.h>
#include <assert.h>

extern "C" {
#include <quadmath.h>
}

#ifndef N
#define N 64
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
  FT wsd;

  for (i = 0 ; i < K ; i++) {
    __float128 in_data;
    fread(&in_data, sizeof(__float128), 1, infile);
    data[i] = (float) in_data;
  }

  for (i = 0 ; i < K ; i++) {
    __float128 in_data;
    fread(&in_data, sizeof(__float128), 1, infile);
    w[i] = (float) in_data;
  }

  fclose(infile);

  // library call
  double wmean;
  #if(FB==64)
    wmean   = gsl_stats_wmean(w, 1, data, 1, K);
    wsd     = gsl_stats_wsd_m(w, 1, data, 1, K, wmean);
  #elif(FB==80)
    wmean   = gsl_stats_long_double_wmean(w, 1, data, 1, K);
    wsd     = gsl_stats_long_double_wsd_m(w, 1, data, 1, K, wmean);
  #else
    exit(-1);
  #endif

  //printf ("The sample wsd is %g\n", wsd);

  __float128 out_data;
  out_data = (__float128) wsd;
  fwrite(&out_data, sizeof(__float128), 1, outfile);
  fclose(outfile);

  return 0;
}
