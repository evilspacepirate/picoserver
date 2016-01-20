--
--  Copyright (c) 2016, John Leimon
--
--  Permission to use, copy, modify, and/or distribute this
--  software for any purpose with or without fee is hereby
--  granted, provided that the above copyright notice and
--  this permission notice appear in all copies.
--
--  THE SOFTWARE IS PROVIDED "AS IS" AND THE AUTHOR DISCLAIMS
--  ALL WARRANTIES WITH REGARD TO THIS SOFTWARE INCLUDING ALL
--  IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS. IN NO
--  EVENT SHALL THE AUTHOR BE LIABLE FOR ANY SPECIAL, DIRECT,
--  INDIRECT, OR CONSEQUENTIAL DAMAGES OR ANY DAMAGES
--  WHATSOEVER RESULTING FROM LOSS OF USE, DATA OR PROFITS,
--  WHETHER IN AN ACTION OF CONTRACT, NEGLIGENCE OR OTHER
--  TORTIOUS ACTION, ARISING OUT OF OR IN CONNECTION WITH THE
--  USE OR PERFORMANCE OF THIS SOFTWARE.
--
with ada.exceptions;    use ada.exceptions;
with ada.io_exceptions; use ada.io_exceptions;
with gnat.sockets;      use gnat.sockets;
with ada.text_io;       use ada.text_io;

package body network is

   task body server is
      type state is (uninitialized, ready, stop);

      LF : constant character := character'val(16#0A#);
      CR : constant character := character'val(16#0D#);
      NL : constant string    := CR & LF;

      ACCEPT_BLOCKING_DURATION_LIMIT : constant duration := 5.0;

      content      : string  := "<!doctype html><html><title>Hello World!</title><body>Hello World!</body></html>";
                   
      response     : string := "HTTP/1.1 200 OK" & NL &
                               "X-Version: MIL-STD-1815A" & NL &
                               "Content-Type: text/html" & NL &
                               "Content-Length:" & natural'image(content'length) & NL &
                               "Connection: close" & NL & NL &
                               content;

      receiver     : gnat.sockets.socket_type;
      connection   : gnat.sockets.socket_type;
      client       : gnat.sockets.sock_addr_type;
      channel      : gnat.sockets.stream_access;

      server_state : state := uninitialized;
      status       : gnat.sockets.selector_status;
   begin
      loop
        select
           accept start (listen_port : in tcp_port) do

              create_socket (socket => receiver);
              set_socket_option
                 (socket => receiver,
                  option => (name    => gnat.sockets.reuse_address,
                             enabled => true));
              bind_socket
                 (socket  => receiver,
                  address => (family => family_inet,
                              addr   => inet_addr ("0.0.0.0"),
                              port   => port_type(listen_port)));
              
              put_line("Listening on port:" & tcp_port'image(listen_port));
              server_state := ready;
           end start;
        or
           accept stop do
              put_line("Shutting down!");
              server_state := stop;
           end stop;
        else 
           null;
        end select;

        case server_state is
           when uninitialized =>
              null;
           when stop => 
              exit;
           when ready =>
              begin
                 listen_socket(socket => receiver);
                 accept_socket
                    (server  => receiver,
                     socket  => connection,
                     timeout => ACCEPT_BLOCKING_DURATION_LIMIT,
                     status  => status,
                     address => client);
                 if status = completed then
                    put_line("PICOSERVER: Client connected from " & gnat.sockets.image(client));
                    channel := gnat.sockets.stream(connection);
                       string'write(channel, response);
                    close_socket(connection);
                 end if;
              end;
        end case;
      end loop;
   end server;

end network;
