// A demo as part of Blimp's walkthrough
// Simple version without printf to avoid linking issues

#include "utils/blimp_stdlib.h"

float fadd(float a, float b)
{
  return a + b;
}

int main()
{

  // // Trash all integer registers
  // volatile int x = 0;
  // for (int i = 0; i < 1000; i++) {
  //   x += i;
  // }

  float a = 1.25f;
  float b = 2.0f; 
  float c = fadd(a, b);

  // Convert to int: 3.25 to 3
  int result = (int)c;
  
  return result;  // Should return 3 if FP works correctly
}
