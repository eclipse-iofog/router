FROM ubuntu:22.04 AS qpid-builder

ENV TZ=Europe/Berlin
ENV DEBIAN_FRONTEND=noninteractive

RUN apt-get update && \
    apt-get install -y curl gcc g++ automake libwebsockets-dev libtool zlib1g-dev cmake libsasl2-dev libssl-dev python3-dev python3-venv python-is-python3 libstdc++-11-dev libuv1-dev sasl2-bin swig maven git && \
    apt-get -y clean

RUN git clone https://gitbox.apache.org/repos/asf/qpid-dispatch.git && cd /qpid-dispatch && git submodule add https://gitbox.apache.org/repos/asf/qpid-proton.git && git submodule update --init

WORKDIR /qpid-dispatch

RUN mkdir qpid-proton/build && cd qpid-proton/build && cmake .. -DSYSINSTALL_BINDINGS=ON -DCMAKE_INSTALL_PREFIX=/usr -DSYSINSTALL_PYTHON=ON && make install

WORKDIR /qpid-dispatch
RUN sed -i '1i #include <cstdint>' /qpid-dispatch/tests/cpp-stub/cpp_stub.h
RUN mkdir build && cd build && cmake .. -DCMAKE_INSTALL_PREFIX=/usr -DUSE_VALGRIND=NO && cmake --build . --target install



FROM golang:1.20.14-alpine AS go-builder

ARG TARGETOS
ARG TARGETARCH

RUN mkdir -p /go/src/github.com/datasance/router
WORKDIR /go/src/github.com/datasance/router
COPY . /go/src/github.com/datasance/router
RUN GOOS=${TARGETOS} GOARCH=${TARGETARCH} go build -o bin/router

FROM ubuntu:22.04

RUN apt-get update && \
    apt-get install -y python3 python-is-python3 iputils-ping && \
    apt-get -y clean

COPY --from=qpid-builder /usr/lib/lib* /usr/lib/
COPY --from=qpid-builder /usr/lib/qpid-dispatch /usr/lib/qpid-dispatch
COPY --from=qpid-builder /usr/lib/python3 /usr/lib/python3
COPY --from=qpid-builder /usr/lib/ssl /usr/lib/ssl
COPY --from=qpid-builder /usr/lib/sasl2 /usr/lib/sasl2
COPY --from=qpid-builder /usr/lib/openssh /usr/lib/openssh
COPY --from=qpid-builder /usr/lib/*-linux-* /usr/lib/
COPY --from=qpid-builder /usr/sbin/qdrouterd /usr/sbin/qdrouterd
COPY --from=qpid-builder /usr/bin/qdmanage /usr/bin/qdmanage
COPY --from=qpid-builder /usr/bin/qdstat /usr/bin/qdstat

COPY --from=go-builder /go/src/github.com/datasance/router/bin/router /qpid-dispatch/router

COPY scripts/launch.sh /qpid-dispatch/launch.sh

ENV PYTHONPATH=/usr/lib/python3/site-packages

CMD ["/qpid-dispatch/router"]