#!/usr/bin/env perl
use strict;
use warnings;
use Mojolicious::Lite;
use utf8;
use Encode qw(encode);
use Config::Simple;
use Net::WebSocket::Server;
use DBI;
use JSON qw(decode_json);

my $cfg = new Config::Simple('chat_config.cfg');

my @mchatters;

websocket '/chat' => sub {

    my $conn = shift;
    push @mchatters, $conn->tx; #Add the user, if message from him is received
    
    $conn->inactivity_timeout(0);
    $conn->on(message => sub {
        my ($web, $msg) = @_;    
        $msg = encode("utf8",$msg);#utf8 support for Cyrillic letters
        my ($srv, $chat_user, $user_msg) = @{decode_json($msg)}; #To solve the issue with inability to use : in user name
        #Remove dangerous tags from User Name and User Message based on https://www.experts-exchange.com/questions/22664900/Extensive-list-of-all-dangerous-HTML-tags-and-attributes-anti-XSS.html
        $srv = $conn->cleanhtml($srv); 
        $chat_user = $conn->cleanhtml($chat_user); 
        $user_msg = $conn->cleanhtml($user_msg);
        #End removing dangerous tags from User Name and User Message
        if ($srv eq "msg") {
            if (length($chat_user) > 255) {
                $msg = substr($chat_user,0,255); #Strip nickname to 255
            }
            if (length($user_msg) > 255) {
                $msg = substr($user_msg,0,255); #Strip message to twit size
            }
            $conn->historyadd($chat_user, $user_msg);
            
            $_->send("$chat_user:$user_msg") for @mchatters;
            
        } else {
            $msg = $conn->gethistory();
            $conn->send($msg);
        }
    });
};
helper 'historyadd' => sub {

    my $self = shift;
    my $name = shift;
    my $msg = shift;

    my $conn_line = "DBI:Pg:dbname=" . $cfg->param('db_name') . ";host=" . $cfg->param('db_host');
    my $myConnection = DBI->connect($conn_line, $cfg->param('db_user'), $cfg->param('db_pass')) || die "Can not connect to the database " . DBI->errstr;
    
    my $query = $myConnection->prepare("INSERT INTO history (username,message) VALUES (?,?)");
    my $result = $query->execute($name, $msg) || die "Can not execute query " .  DBI->errstr;
    $query->finish();
    $myConnection->disconnect;
   
    return;
    
};

helper 'gethistory' => sub {

    my $self = shift;
    
    my $conn_line = "DBI:Pg:dbname=" . $cfg->param('db_name') . ";host=" . $cfg->param('db_host');
    my $myConnection = DBI->connect($conn_line, $cfg->param('db_user'), $cfg->param('db_pass')) || die "Can not connect to the database " .  DBI->errstr;
    my $query;
  
    $query = $myConnection->prepare("SELECT username,message FROM history WHERE date_created='NOW()'");
  
    my $result = $query->execute() || die "Can not execute query " .  DBI->errstr;
    if ($result != '0E0') {
        my $msg = "";
        while (my $item = $query->fetchrow_hashref) {
            $msg .=   $item->{username} . ":" . $item->{message} . "<br/>";            
        }
        #Notify User about chat rules in regards to dangerous tags
        $msg .= " :" . "Данный чат является преимущественно текстовым с ограничением по использованию HTML тэгов - запрещённые HTML тэги будут удалены системой автоматически.<br/>Сообщения ограничены 255 символами.<br/>";
        return $msg;
    } else {
        my $msg = " :" . "Данный чат является преимущественно текстовым с ограничением по использованию HTML тэгов - запрещённые HTML тэги будут удалены системой автоматически.<br/>Сообщения ограничены 255 символами.<br/>";
        return $msg;
    }
    $query->finish();
    $myConnection->disconnect;

    return;
    
};

helper 'cleanhtml' => sub {
    # Helper function to remove dangerous tags based on https://www.experts-exchange.com/questions/22664900/Extensive-list-of-all-dangerous-HTML-tags-and-attributes-anti-XSS.html
    my $self = shift;
    my $line = shift;
    my @dangeroushtmltags = ("<FORM>","</FORM>","<A>","<IMG>","<NOFRAMES>","</NOFRAMES>","<NOSCRIPT>","</NOSCRIPT>","<MARQUEE>","</MARQUEE>","<PLAINTEXT>","</PLAINTEXT>","<REPLACE>","</REPLACE>","<STYLE>","</STYLE>","<BUTTON>","<INPUT>","<TEXTAREA>","</TEXTAREA>","<SELECT>","</SELECT>","<BLINK>","</BLINK>","<XML>","</XML>","<BASE>","</BASE>","<HTML>","</HTML>","<HEAD>","</HEAD>","<TITLE>","</TITLE>","<BODY>","</BODY>","<APPLET>","</APPLET>","<SCRIPT>","</SCRIPT>","<OBJECT>","</OBJECT>","<EMBED>","</EMBED>","<IFRAME>","</IFRAME>","<FRAME>","</FRAME>","<LAYER>","</LAYER>","<ILAYER>","</ILAYER>","<META>","<BGSOUND>","<LINK>","<ISINDEX>","<NEXTID>");

    my $returned = $line;
    foreach (@dangeroushtmltags) {
        my $lowercase = lc($_);
        $returned =~ s/\Q$_//g ;
        $returned =~ s/\Q$lowercase//g ;
     }
    
    return $returned;
};

get '/' => sub {
  my $c = shift;
  $c->render(template => 'index');
};

app->start;
__DATA__

@@ index.html.ep
% layout 'default';
% title 'Chat';


@@ layouts/default.html.ep
<!DOCTYPE html>
<html>
    <head>
        <meta http-equiv="content-type" content="text/html; charset=utf-8" />
        <title><%= title %></title>
        <style>
        #chatWindow {
            width: 500px;
            height:300px;
            border: 1px solid black;
            background-color: white;
            overflow-y:auto;
        }
        #chatControls {
            margin-top: 5px;
            width: 500px;
            height: 35px;
            border: 1px solid black;
            text-align:center;	
        }
        .inner {   
            margin-top: 5px;
        }
        </style>
        <script src="https://ajax.googleapis.com/ajax/libs/jquery/2.2.0/jquery.min.js"></script>
    </head>
    <body>
        <div id="chat">
            <div id="chatWindow"></div>
            <div id="chatControls">
                <input  type="text" id="name" placeholder="anonymous" class="inner"/>:
                <input id="chatMsg" type="text" placeholder="your message" class="inner"/>
                <button id="sendChat" class="inner">Chat It!</button>
            </div>
        </div>
    </body>
    <script>    
    var ws = new WebSocket('<%= url_for('chat')->to_abs %>');
    console.log('<%= url_for('chat')->to_abs %>');
    $( "#sendChat" ).click(function() {
        var name = $("#name");
        var chatMsg = $("#chatMsg");
        name = name.val() ? name.val() : "anonymous";
        chatMsg = chatMsg.val() ? chatMsg.val() : "your message";
        
        var message = ["msg", name, chatMsg];
        message = JSON.stringify(message);  //To solve the issue with inability to use : in user name
        try {            
            ws.send( message );            
        } catch (error) {
            console.log (error);
        }
    });
    ws.onmessage = function( event ) {
        var message = event.data;
        chatWindow = $("#chatWindow");
        $("#chatWindow").append( message + '<br/>' );
        $("#chatWindow").scrollTop( $("#chatWindow").prop( 'scrollHeight' ) );
    };
    
    setTimeout(updateHistory, 1000); //To get history on page reload - that is not a polling - the event will not repeat - it is just a delay after page re-load or re-fresh and firing an event
    function updateHistory() {
        var message = ["srv", "get", "history"]; 
        message = JSON.stringify(message); //To solve the issue with inability to use : in user name
        try {            
            ws.send( message );           
        } catch (error) {
            console.log (error);
        }
    }
</script>
</html>
