# Build GraalVM Complete

The purpose of this script is to build a *complete* GraalVM. That is a build of GraalVM with everything installed an all native-images rebuilt to include all the languages.

You should have a directory called something like `graalvm-ce-java8-darwin-amd64-21.0.0` that contains the tarball and whatever installables and other tools you want. You need to download these yourself. For example:

```
% ls graalvm-ce-java8-darwin-amd64-21.0.0/*
graalvm-ce-java8-darwin-amd64-21.0.0/c1visualizer-1.7.zip
graalvm-ce-java8-darwin-amd64-21.0.0/espresso-installable-java8-darwin-amd64-21.0.0.jar
graalvm-ce-java8-darwin-amd64-21.0.0/graalvm-ce-java8-darwin-amd64-21.0.0.tar.gz
graalvm-ce-java8-darwin-amd64-21.0.0/llvm-toolchain-installable-java8-darwin-amd64-21.0.0.jar
graalvm-ce-java8-darwin-amd64-21.0.0/native-image-installable-svm-java8-darwin-amd64-21.0.0.jar
graalvm-ce-java8-darwin-amd64-21.0.0/python-installable-svm-java8-darwin-amd64-21.0.0.jar
graalvm-ce-java8-darwin-amd64-21.0.0/ruby-installable-svm-java8-darwin-amd64-21.0.0.jar
graalvm-ce-java8-darwin-amd64-21.0.0/wasm-installable-svm-java8-darwin-amd64-21.0.0.jar
```

Then run this tool. This will probably take a very long time to run as it's compiling the universe multiple times.

```
% ruby build-graalvm-complete/build-graalvm-complete.rb graalvm-ce-java8-darwin-amd64-21.0.0
...
```

Now you'll have a complete tarball with all installables installed, and all native images rebuilt.

```
% du -h graalvm-ce-java8-darwin-amd64-21.0.0-complete.tar.gz
784M	graalvm-ce-java8-darwin-amd64-21.0.0-complete.tar.gz
% tar -zxf graalvm-ce-java8-darwin-amd64-21.0.0-complete.tar.gz
% ./graalvm-ce-java8-darwin-amd64-21.0.0-complete/Contents/Home/bin/polyglot --version:graalvm
GraalVM CE Native Polyglot Engine Version 21.0.0
Java Version 1.8.0_282
Java VM Version GraalVM 21.0.0 Java 8 CE
GraalVM Home .../graalvm-ce-java8-darwin-amd64-21.0.0-complete/Contents/Home
  Installed Languages:
    Java       version 1.8|11
    JavaScript version 21.0.0
    LLVM       version 10.0.0
    Python     version 3.8.5
    Ruby       version 2.7.2
...
```

Check you understand the licences before you use or redistribute it! I think you should not make it available publicly, but not I'm not a lawyer.

MIT licence. By Chris Seaton at Shopify.
