FROM golang:1.16.4-stretch
RUN apt-get update -y
RUN apt-get install ca-certificates libgnutls30 -y
RUN chmod 755 /etc /etc/ssl /etc/ssl/certs
RUN chmod 644 /etc/ssl/certs/ca-certificates.crt
# Setup
WORKDIR /build
RUN ls -all
COPY go.* ./
COPY *.go ./

# Install older version of GopherJS
#RUN go get github.com/gopherjs/gopherjs@1.12.3+go1.12
RUN go get github.com/gopherjs/gopherjs@1.16.4+go1.16.7

# Special sauce part 1
RUN go mod vendor

# Special sauce part 2 - copy to GOPATH
RUN mkdir -p /go/src/hcl2-parser
RUN cp -r * /go/src/hcl2-parser
WORKDIR /go/src/hcl2-parser

# Finally we can build
RUN gopherjs build parser.go -o index.js -m

#COPY build/copy-out.sh .
#ENTRYPOINT ["/go/src/hcl2-parser/copy-out.sh"]