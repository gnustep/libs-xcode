#include <stdlib.h>
#include <strings.h>
#include <stdio.h>

int setenv(const char *key, const char *value, int overwrite)
{
  int result = 255; // failure...
  char *current = getenv(key);
  if(overwrite && current)
    {
      int key_len = strlen(key);
      int val_len = strlen(value);
      int len = key_len + 1 + val_len + 1; // key + "=" + value + '\0'
      char *buffer = malloc(len);
      memset(buffer, 0, len);
      sprintf(buffer,"%s=%s",key,value);
      result = putenv(buffer);
      free(buffer);
    }
  return result;
}
