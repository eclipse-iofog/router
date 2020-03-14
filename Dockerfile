FROM ubuntu:latest AS builder

RUN apt-get update && \
    apt-get install -y gcc g++ automake libtool zlib1g-dev cmake libsasl2-dev libssl-dev python python-dev libuv1-dev sasl2-bin swig maven git && \
    apt-get -y clean

RUN git clone https://gitbox.apache.org/repos/asf/qpid-dispatch.git && cd /qpid-dispatch && git submodule add -b v2.1-stable https://github.com/warmcat/libwebsockets && git submodule add https://gitbox.apache.org/repos/asf/qpid-proton.git && git submodule update --init

WORKDIR /qpid-dispatch

RUN mkdir libwebsockets/build && cd /qpid-dispatch/libwebsockets/build && cmake .. -DCMAKE_INSTALL_PREFIX=/usr && make install

WORKDIR /qpid-dispatch

RUN mkdir qpid-proton/build && cd qpid-proton/build && cmake .. -DSYSINSTALL_BINDINGS=ON -DCMAKE_INSTALL_PREFIX=/usr -DSYSINSTALL_PYTHON=ON && make install

WORKDIR /qpid-dispatch

RUN mkdir build && cd build && cmake .. -DCMAKE_INSTALL_PREFIX=/usr -DUSE_VALGRIND=NO && cmake --build . --target install

FROM ubuntu:latest

COPY --from=builder /usr/lib/lib* /usr/lib/
COPY --from=builder /usr/lib/qpid-dispatch /usr/lib/qpid-dispatch
COPY --from=builder /usr/lib/python2.7 /usr/lib/python2.7
COPY --from=builder /usr/lib/ssl /usr/lib/ssl
COPY --from=builder /usr/lib/sasl2 /usr/lib/sasl2
COPY --from=builder /usr/lib/openssh /usr/lib/openssh
COPY --from=builder /usr/lib/*-linux-* /usr/lib/
COPY --from=builder /usr/sbin/qdrouterd /usr/sbin/qdrouterd

ENV PYTHONPATH=/usr/lib/python2.7/site-packages

COPY launch.sh /qpid-dispatch/launch.sh

ENTRYPOINT ["/qpid-dispatch/launch.sh"]
