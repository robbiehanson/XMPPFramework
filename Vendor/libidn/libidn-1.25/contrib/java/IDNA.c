#include <jni.h>
#include "IDNA.h"

JNIEXPORT jstring JNICALL
Java_IDNA_toAscii(JNIEnv *env, jobject obj, jstring jstr)
{
  const char *in;
  const char *out;
  int rc;

  in = (*env)->GetStringUTFChars(env, jstr, 0);

  rc = idna_to_ascii_from_utf8 (in, &out, 0, 0);

  (*env)->ReleaseStringUTFChars(env, jstr, in);

  return (*env)->NewStringUTF(env, out);
}
