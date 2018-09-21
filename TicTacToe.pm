#
# TicTacToe.pm
# 

use strict;

package TicTacToe;

srand;

sub new {
    my ($proto, %arg ) = @_;
    
    my $class = ref($proto) || $proto;

    my $self = {};

    foreach (keys %arg) {
        $arg{data}{$_} = $arg{$_};
        undef $arg{$_};
    }

    bless ($self, $class);
    return $self;
}



sub initialize {
    my ($self, $arg) = @_;

    # Set space characters in all the spaces:
    #
    foreach my $row (1..3) {
        foreach my $col (65..67) { # A B C
            $self->{coords}{"$row"}{chr($col)} = ' ';
        }
    }
    
    $self->{num_plays} = 0;
}


#sub show_board {
#    my ($self, $arg) = @_;
#
#    print qq~    A   B   C\n~;
#    print qq~\n~;
#    print qq~1   $self->{coords}{1}{'A'} | $self->{coords}{1}{'B'} | $self->{coords}{1}{'C'} \n~;
#    print qq~   --- --- ---\n~;
#    print qq~2   $self->{coords}{2}{'A'} | $self->{coords}{2}{'B'} | $self->{coords}{2}{'C'} \n~;
#    print qq~   --- --- ---\n~;
#    print qq~3   $self->{coords}{3}{'A'} | $self->{coords}{3}{'B'} | $self->{coords}{3}{'C'} \n~;
#
#    print qq~\n~;
#}


sub show_board {
    my ($self, $arg) = @_;

    my $d;

    $d .= qq~    A   B   C\n~;
    $d .= qq~1   $self->{coords}{1}{'A'} I $self->{coords}{1}{'B'} I $self->{coords}{1}{'C'} \n~;
    $d .= qq~   --- --- ---\n~;
    $d .= qq~2   $self->{coords}{2}{'A'} I $self->{coords}{2}{'B'} I $self->{coords}{2}{'C'} \n~;
    $d .= qq~   --- --- ---\n~;
    $d .= qq~3   $self->{coords}{3}{'A'} I $self->{coords}{3}{'B'} I $self->{coords}{3}{'C'} \n~;

    
    return $d;
}


sub validate_and_perform_turn {
    my ($self, $move_coords, $character) = @_;

    # We're assuming that the input is valid for the game board, and we're only
    # verifying that the move is legit; IE that there isn't a piece already in the space.

    my $row = substr($move_coords, 0, 1);
    my $col = substr($move_coords, 1, 1);
    
    print "\nmove_coords: --$move_coords-- Can we play in row: --$row--   col: --$col--\n";


    
    if ($col =~ /\d+/) { # Column has the number, swap with row!
        my $tmp = $col;
        $col = $row;
        $row = $tmp;
    }
    


    
    if (!$self->{coords}{$row}{$col} or $self->{coords}{$row}{$col} eq ' ') {
        $self->{coords}{$row}{$col} = $character || '*';
        
        $self->{num_plays}++;

        return 1;
    }
    
    return 0;
}

sub check_for_win {
    my ($self, $character) = @_;
    
    # Check to see if whoever played $character has won
    # There are 8 ways to win, and iteration would be nice to determine this case!
    # See check_for_winning_move()
    
    return 1 if ( $self->{coords}{'1'}{'A'} eq $character and 
                  $self->{coords}{'1'}{'B'} eq $character and
                  $self->{coords}{'1'}{'C'} eq $character);

    return 1 if ( $self->{coords}{'2'}{'A'} eq $character and 
                  $self->{coords}{'2'}{'B'} eq $character and
                  $self->{coords}{'2'}{'C'} eq $character);

    return 1 if ( $self->{coords}{'3'}{'A'} eq $character and 
                  $self->{coords}{'3'}{'B'} eq $character and
                  $self->{coords}{'3'}{'C'} eq $character);
                  
    return 1 if ( $self->{coords}{'1'}{'A'} eq $character and 
                  $self->{coords}{'2'}{'A'} eq $character and
                  $self->{coords}{'3'}{'A'} eq $character);                  

    return 1 if ( $self->{coords}{'1'}{'B'} eq $character and 
                  $self->{coords}{'2'}{'B'} eq $character and
                  $self->{coords}{'3'}{'B'} eq $character); 

    return 1 if ( $self->{coords}{'1'}{'C'} eq $character and 
                  $self->{coords}{'2'}{'C'} eq $character and
                  $self->{coords}{'3'}{'C'} eq $character);                   

    # Now for the diagonal win check: (pretty sneaky, sis!)

    return 1 if ( $self->{coords}{'1'}{'A'} eq $character and 
                  $self->{coords}{'2'}{'B'} eq $character and
                  $self->{coords}{'3'}{'C'} eq $character);     

    return 1 if ( $self->{coords}{'3'}{'A'} eq $character and 
                  $self->{coords}{'2'}{'B'} eq $character and
                  $self->{coords}{'1'}{'C'} eq $character);     
    
    return 0;
}




sub check_for_winning_move {
    my ($self, $character) = @_;
    
#    print "\nin check_for_winning_move() for character: --$character--\n";
    
    # Check to see if whoever is $character has an impending win.
    # The coordinates of the winning move are returned, IE: 1A
    #
    
    
    # Row check:
    #
    foreach my $row (1..3) {
        my $num_char = 0; # The number of spaces containing $character in this row
        my $num_open = 0; # Number of open spaces in this row
        my $open_row;     # The row where there's an open space, or at least the last we've checked.
        my $open_col;     # The col where there's an open space, or at least the last we've checked.
    
        foreach my $col (65..67) { # A B C
            $num_char++ if ($self->{coords}{$row}{chr($col)} eq $character);

            if ($self->{coords}{$row}{chr($col)} eq ' ') {
                $num_open++;

                $open_row = $row;
                $open_col = chr($col);
            }
        }
        
        if ($num_char == 2 and $num_open == 1) { # $character can win!
            return "$open_row$open_col";
        }
    }


    # Column check:
    #
    foreach my $col (65..67) { # A B C    
        my $num_char = 0; # The number of spaces containing $character in this column
        my $num_open = 0; # Number of open spaces in this column
        my $open_row;     # The row where there's an open space, or at least the last we've checked.
        my $open_col;     # The col where there's an open space, or at least the last we've checked.
    
        foreach my $row (1..3) {
            $num_char++ if ($self->{coords}{$row}{chr($col)} eq $character);

            if ($self->{coords}{$row}{chr($col)} eq ' ') {
                $num_open++;

                $open_row = $row;
                $open_col = chr($col);
            }
        }
        
        if ($num_char == 2 and $num_open == 1) { # $character can win!
            return "$open_row$open_col";
        }
    }


    # Diagonal check 1A - 3C
    # 
    my $col = 65;
    my $num_char = 0; # The number of spaces containing $character in this column
    my $num_open = 0; # Number of open spaces in this column
    my $open_row;     # The row where there's an open space, or at least the last we've checked.
    my $open_col;     # The col where there's an open space, or at least the last we've checked.

    foreach my $row (1..3) {

        $num_char++ if ($self->{coords}{$row}{chr($col)} eq $character);

        if ($self->{coords}{$row}{chr($col)} eq ' ') {
            $num_open++;

            $open_row = $row;
            $open_col = chr($col);
        }
        $col++;
    }    
    if ($num_char == 2 and $num_open == 1) { # $character can win!
        return "$open_row$open_col";
    }    

    # Diagonal check 3A - 1C
    # 
    my $col = 67;
    my $num_char = 0; # The number of spaces containing $character in this column
    my $num_open = 0; # Number of open spaces in this column
    my $open_row;     # The row where there's an open space, or at least the last we've checked.
    my $open_col;     # The col where there's an open space, or at least the last we've checked.

    foreach my $row (1..3) {

        $num_char++ if ($self->{coords}{$row}{chr($col)} eq $character);

        if ($self->{coords}{$row}{chr($col)} eq ' ') {
            $num_open++;

            $open_row = $row;
            $open_col = chr($col);
        }
        $col--;
    }
    
    print "In Diagonal check 3A - 1C\n";
    print "num_char: --$num_char--  num_open: --$num_open--\n";
    
    if ($num_char == 2 and $num_open == 1) { # $character can win!
        return "$open_row$open_col";
    }  
    
    return;
}










sub computer_make_intelligent_turn {
    my ($self) = @_;
   
    print "I am thinking of a play..";

    # Look to see if we can win on this play.
    #
    my $winning_move = $self->check_for_winning_move($self->{computer_character});
    
    if ($winning_move) { # We can win!
        $self->validate_and_perform_turn("$winning_move", $self->{computer_character});
        return;
    }

    # Check to see if the human can win, so we can block him if so!
    #
    my $winning_move = $self->check_for_winning_move($self->{player_character});
    
    if ($winning_move) { # We can win!
        $self->validate_and_perform_turn("$winning_move", $self->{computer_character});
        return;
    }

    # Just make a random move 

    $self->computer_make_random_move();
    
    return;
}

sub computer_make_random_move {
    my ($self) = @_;
   
    # Ideally we'd look to block the human player, but
    # let's just make random moves for now!

    foreach (1..9) {
        print '.';
        my $random_row = int(rand 3) + 1;
        my $random_col = chr( int(rand 3) + 65);

#        print "\nin computer_make_turn(), random_row: --$random_row--  random_col: --$random_col--\n";
    
        if ($self->validate_and_perform_turn("$random_row$random_col", $self->{computer_character})) {
            last;
        }
    }

}



















