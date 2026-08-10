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

package main

import (
	"context"
	"testing"

	pb "google.golang.org/grpc/examples/helloworld/helloworld"
)

func TestSayHello(t *testing.T) {
	tests := []struct {
		name    string
		reqName string
		wantMsg string
		wantErr bool
	}{
		{
			name:    "happy path",
			reqName: "world",
			wantMsg: "Hello world",
		},
		{
			name:    "empty name",
			reqName: "",
			wantMsg: "Hello ",
		},
	}

	for _, tt := range tests {
		tt := tt
		t.Run(tt.name, func(t *testing.T) {
			s := &server{}
			reply, err := s.SayHello(context.Background(), &pb.HelloRequest{Name: tt.reqName})
			if tt.wantErr {
				if err == nil {
					t.Fatalf("expected error, got nil")
				}
				return
			}
			if err != nil {
				t.Fatalf("unexpected error: %v", err)
			}
			if reply.GetMessage() != tt.wantMsg {
				t.Errorf("SayHello() = %q, want %q", reply.GetMessage(), tt.wantMsg)
			}
		})
	}
}
