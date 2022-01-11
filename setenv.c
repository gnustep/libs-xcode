/*
   Copyright (C) 2018, 2019, 2020, 2021 Free Software Foundation, Inc.

   Written by: Gregory John Casament <greg.casamento@gmail.com>
   Date: 2022
   
   This file is part of the GNUstep XCode Library

   This library is free software; you can redistribute it and/or
   modify it under the terms of the GNU Lesser General Public
   License as published by the Free Software Foundation; either
   version 2 of the License, or (at your option) any later version.
   
   This library is distributed in the hope that it will be useful,
   but WITHOUT ANY WARRANTY; without even the implied warranty of
   MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
   Lesser General Public License for more details.
   
   You should have received a copy of the GNU Lesser General Public
   License along with this library; if not, write to the Free
   Software Foundation, Inc., 51 Franklin Street, Fifth Floor,
   Boston, MA 02110 USA.
*/ #include <stdlib.h>
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
