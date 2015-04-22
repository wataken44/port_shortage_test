#!/usr/bin/env ruby
# -*- coding: utf-8 -*-

# test.rb

require 'logger'
require 'optparse'
require 'socket'

DEFAULT_PORT = 51000

LOGGERS = []

def log(message, severity=Logger::INFO)
    LOGGERS.each do |logger|
        logger.log(severity, message)
    end
end

def split_addr_port(s)
    arr = s.split(":")
    addr = arr[0]
    port = (arr.size == 2 ? arr[1].to_i : DEFAULT_PORT)

    return addr, port
end

def create_client_thread(clients)
    threads = []
    threads << Thread.new(clients) do |clients|
        log("[client] start %s" % clients.join(" "))
        finished = false
        sockets = []
        counter = 0

        while !finished do 
            clients.each do |c|
                socket = Socket.new(Socket::AF_INET, Socket::SOCK_STREAM, 0)
                addr, port = split_addr_port(c)
                sockaddr = Socket.sockaddr_in(port, addr)

                begin
                    counter += 1
                    socket.connect(sockaddr)
                    log("[client] connect %5d socket(%s:%s)" % [counter, addr, port])
                rescue => err
                    log("[client] " + err.to_s, Logger::ERROR)
                    finished = true
                end
                sockets << socket
            end
        end
        log("[client] waiting 1min.")
        sleep(60)
        sockets.each do |socket|
            socket.close()
        end
    end
    return threads
end

def create_server_threads(servers)
    threads = []
    servers.each do |server|
        addr, port = split_addr_port(server)
        threads << Thread.new(addr, port) do |addr, port|
            log("[server] start %s:%s" % [addr, port])
            finished = false

            server_socket = Socket.new(Socket::AF_INET, Socket::SOCK_STREAM, 0)
            server_sockaddr = Socket.sockaddr_in(port, addr)
            server_socket.bind(server_sockaddr)
            log("[server] bind %s:%s" % [addr, port])

            server_socket.listen(16)
            log("[server] listen %s:%s" % [addr, port])
            
            client_sockets = []
            counter = 0

            while !finished do
                counter += 1
                begin
                    socket, client_sockaddr = server_socket.accept()
                    ap, aa = Socket.unpack_sockaddr_in(client_sockaddr)
                    log("[server] accept %5d socket(%s:%s)" % [counter, aa, ap])
                    client_sockets << socket
                rescue => err
                    log("[server] " + err.to_s, Logger::ERROR)
                    finished = true
                end
                client_sockets << socket
            end
            log("[server] waiting 1min.")
            sleep(60)
            server_socket.close()
            client_sockets.each do |socket|
                socket.close()
            end
        end
    end
    return threads
end

def main()
    LOGGERS << Logger.new(STDOUT)
    fp = open('test.log.txt', 'a')
    LOGGERS << Logger.new(fp)

    clients = []
    servers = []

    opt = OptionParser.new
    opt.on('-c client'){|v| clients << v }
    opt.on('-s server'){|v| servers << v }
    opt.parse(ARGV)

    threads = []
    threads += create_client_thread(clients) if clients.size > 0
    threads += create_server_threads(servers) if servers.size > 0

    threads.each do |th|
        th.join()
    end
    
    fp.close()
end


if __FILE__ == $0 then
    main()
end
