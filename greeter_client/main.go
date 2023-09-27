/*
 *
 * Copyright 2015 gRPC authors.
 *
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *
 *     http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 *
 */

// Package main implements a client for Greeter service.
package main

import (
	"context"
	"flag"
	"log"
	"time"

	"google.golang.org/grpc"
	grpc_retry "github.com/grpc-ecosystem/go-grpc-middleware/retry"
	"google.golang.org/grpc/keepalive"
	"google.golang.org/grpc/credentials/insecure"
	pb "google.golang.org/grpc/examples/helloworld/helloworld"
)

const (
	defaultName = "world"
)

var (
	addr = flag.String("addr", "localhost:50051", "the address to connect to")
	name = flag.String("name", defaultName, "Name to greet")
	alive = flag.Bool("alive", false, "keep connection alive")
)

func main() {
	flag.Parse()
	// Set up a connection to the server.

	opts := []grpc_retry.CallOption{
		grpc_retry.WithMax(5),
		grpc_retry.WithPerRetryTimeout(time.Second*5),
	}

	

	var conn *grpc.ClientConn
	var err error
	if *alive {
		conn, err = grpc.DialContext(context.Background(),*addr, 
		grpc.WithTransportCredentials(insecure.NewCredentials()),
		grpc.WithUnaryInterceptor(grpc_retry.UnaryClientInterceptor(opts...)),
		grpc.WithKeepaliveParams(keepalive.ClientParameters{}),
		)
	} else {
		conn, err = grpc.DialContext(context.Background(),*addr, 
		grpc.WithTransportCredentials(insecure.NewCredentials()),
		grpc.WithUnaryInterceptor(grpc_retry.UnaryClientInterceptor(opts...)),
		)
	}

	if err != nil {
		log.Fatalf("did not connect: %v", err)
	}
	defer conn.Close()
	c := pb.NewGreeterClient(conn)
	
	count := 0
	for {
		log.Print(">>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>")
		log.Printf("New request from client: %d", count)
		count++

		duration := time.Now().Add(45 * time.Second)
		ctx, _ := context.WithDeadline(context.Background(), duration)
		r, err := c.SayHello(ctx, &pb.HelloRequest{Name: *name})
		if err != nil {
			log.Printf("could not greet: %v", err)
		}
		log.Printf("Greeting: %s", r.GetMessage())

		log.Print("Sleeping for 5 seconds")
		log.Print(">>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>")
		time.Sleep(time.Second*5)
	}
}
