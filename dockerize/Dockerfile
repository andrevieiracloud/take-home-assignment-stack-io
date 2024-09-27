FROM golang:1.20

WORKDIR /app

COPY . .

RUN go mod download

RUN go build -o myapp webserver.go

EXPOSE 8080

CMD ["./myapp"]
