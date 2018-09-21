#!/usr/bin/perl
#
# tttt.pl   Teletype-Tic-Tac-Toe
# 
# A simple and hastily-cobbled-together Tic Tac Toe game.
# The goal was to make a teletype-playable game.
#
# 04/04/14 corey@ElectricLab.com
# 

use strict;
use TicTacToe;

use Teletype;


my $teletype = new Teletype;

$teletype->init();

my $config;

my @now = localtime(time); $now[5] += 1900; ++$now[4];
$config->{runtime} = sprintf "%04d-%02d-%02d %02d %02d %02d", @now[5,4,3],@now[2,1,0];

# Set teletype to LTRS:
#$teletype->send_baudot_word_to_teletype( Teletype::transform_custom_character($teletype->{config}{ltrs_or_figs}) );


$teletype->send_baudot_word_to_teletype( Teletype::transform_custom_character('FIGS') );
$teletype->teleprint(chr(7));
$teletype->send_baudot_word_to_teletype( Teletype::transform_custom_character('LTRS') );

$teletype->teleprint("\n$config->{runtime}\n");
$teletype->teleprint("Shall we play a game\n");


while (1) {
    $teletype->teleprint("What is your name \n");
    
    $config->{player_name} = $teletype->read_line();
    
    $config->{player_name} = uc($config->{player_name});  
    
    chomp($config->{player_name});

    print "player_name: --$config->{player_name}--\n";

    last if ($config->{player_name} =~ m/\w+/);
}    


$teletype->teleprint("\nhello $config->{player_name}, lets play tic tac toe\n");

while (1) {
    $teletype->teleprint("Pick X or O \n");

    $config->{player_character} = $teletype->read_line();
    
    $config->{player_character} = uc($config->{player_character});
    
    chomp($config->{player_character});
    
    if ($config->{player_character} eq 'X') {
        $config->{computer_character} = 'O';
        last;
    }
    elsif ($config->{player_character} eq 'O') {
        $config->{computer_character} = 'X';
        last;
    }
    
    $teletype->teleprint("\nPlease enter either X or O\n");
}



my $game = new TicTacToe;

$game->initialize();

$game->{player_name} = $config->{player_name};
$game->{player_character} = $config->{player_character};
$game->{computer_character} = $config->{computer_character};
$game->{current_turn} = 'player';

$teletype->teleprint("\nOK, you will be $game->{player_character} and I will be $game->{computer_character}\n");

while (1) {

    $teletype->teleprint( $game->show_board() );
    
    if ($game->{num_plays} >= 9) {
        $teletype->teleprint("Tie game. maybe the only way to win is not to play.\n");
        $teletype->teleprint("let's play again sometime, $game->{player_name}\n\n");
        exit;
    }

    if ($game->{current_turn} eq 'player') {
        $teletype->teleprint("It is your turn $game->{player_name}, enter your move \n");
        my $player_input = $teletype->read_line();
        
        chomp($player_input);

        print "player_input: --$player_input--\n";
        
        $teletype->teleprint("\n");
        
        $player_input = uc($player_input);
        
        $player_input = &validate_turn_input($player_input);
        
        if (!$player_input) {
            $teletype->teleprint("Invalid input, try again\n");
            next;
        }
        
        if (!$game->validate_and_perform_turn($player_input, $game->{player_character})) {
            $teletype->teleprint("Invalid move, try again\n");
            next;
        }
        else {
            # Player just made a valid play, check to see if we have a win
            
            if ($game->check_for_win($game->{player_character})) {
            
                $teletype->teleprint( $game->show_board() );


                $teletype->send_baudot_word_to_teletype( Teletype::transform_custom_character('FIGS') );
                $teletype->teleprint(chr(7));
                $teletype->send_baudot_word_to_teletype( Teletype::transform_custom_character('LTRS') );


            
                $teletype->teleprint("You won, good job $game->{player_name}\n");
                exit;
            }
        
            $game->{current_turn} = 'computer';

            # Now it's the computer's turn!

            
            $teletype->teleprint("My turn now, $game->{player_name}...\n");

            $game->computer_make_intelligent_turn();
            
            if ($game->check_for_win($game->{computer_character})) {
                $teletype->teleprint( $game->show_board() );

                $teletype->send_baudot_word_to_teletype( Teletype::transform_custom_character('FIGS') );
                $teletype->teleprint(chr(7));
                $teletype->send_baudot_word_to_teletype( Teletype::transform_custom_character('LTRS') );
            
                $teletype->teleprint("I won, sorry $game->{player_name}\n");
                exit;            
            }
            

            $game->{current_turn} = 'player';
            
            next;
        }                        
    }
    
}    
    
    
sub validate_turn_input {
    my $turn = shift;
    
#    $turn =~ s/[^1-3^A-C]//g; # Strip non-allowed characters

    print "validate_turn_input, turn: --$turn--\n";

#    return 0 if ($turn !~ m/[1-3][A-C]/ or length($turn) ne 2);

    return 0 if (length($turn) ne 2);

    return 0 if ($turn !~ m/[1-3][A-C]/ and $turn !~ m/[A-C][1-3]/);

    return $turn;
}

