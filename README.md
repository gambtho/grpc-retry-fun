# modified version of https://github.com/grpc/grpc-go/tree/master/examples/helloworld

# gRPC Hello World

Follow these setup to run the [quick start][] example:

 1. Get the code:

    ```console
    $ go get google.golang.org/grpc/examples/helloworld/greeter_client
    $ go get google.golang.org/grpc/examples/helloworld/greeter_server
    ```

 2. Run the server:

    ```console
    $ $(go env GOPATH)/bin/greeter_server &
    ```

 3. Run the client:

    ```console
    $ $(go env GOPATH)/bin/greeter_client
    Greeting: Hello world
    ```

For more details (including instructions for making a small change to the
example code) or if you're having trouble running this example, see [Quick
Start][].

[quick start]: https://grpc.io/docs/languages/go/quickstart


export GODEBUG=http2debug=2
go run ./greeter_client
go run ./greeter_server
sudo netstat -anp | grep greeter_c
sudo iptables -I INPUT -p tcp --dport <<PORT>> -j DROP