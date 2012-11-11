class IDNA {
    public native String toAscii(String str);

    static {
        System.loadLibrary("idn-java");
    }
}
