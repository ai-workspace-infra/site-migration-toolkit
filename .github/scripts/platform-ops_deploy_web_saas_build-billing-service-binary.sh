#!/bin/bash
go build -buildvcs=false -o dist/billing-service-linux-amd64 ./cmd/billing-service
chmod 0755 dist/billing-service-linux-amd64
