#### modified version of https://github.com/grpc/grpc-go/tree/master/examples/helloworld

# gRPC Hello World

## Prerequisites

- Go 1.19 (as specified in `/home/runner/_work/grpc-retry-fun/grpc-retry-fun/go.mod`)
- `protoc` is only required when regenerating the gRPC stubs

Follow these steps (Linux only):

 1. Run the server:

    ```console
    $ go run ./greeter_client
    ```

 2. Run the client in a new terminal window:

    ```console
    export GODEBUG=http2debug=2
    go run ./greeter_client -name=no_reconnect
    ```
    
 3. Run the client in a new terminal window:

    ```console
    export GODEBUG=http2debug=2
    go run ./greeter_client -name=reconnect -alive
    ```

4. In yet another terminal window:

   ```console
    sudo netstat -anp | grep greeter_c # use port from here in the line below
    sudo iptables -I INPUT -p tcp --dport <<PORT>> -j DROP
    ```
   
5. Observe the behavior in the two client terminals
   - reconnect client will have a single timeout, then reconnect
   - no_reconnect client will have repeated timeouts
