#
# Teletype.pm
#
# Corey J. Anderson 
#
# 04/04/14
#

use strict;
use Device::BCM2835;


package Teletype;



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

sub init {
    my ($self, $arg) = @_;

    # Autoflush STDOUT to disable unwanted buffering:
    # 
    open STDERR, '>&STDOUT' or die "Could not dup stderr";
    flush STDOUT;
                   
    local $| = 1;

    Device::BCM2835::init() || die "Could not init library";
    
    
    # Configure RPi pin 6 to be an output
    Device::BCM2835::gpio_fsel( &Device::BCM2835::RPI_GPIO_P1_11,
                                &Device::BCM2835::BCM2835_GPIO_FSEL_OUTP);
                                
    # Configure RPi pin 11 (GPIO 17) to be an output
    Device::BCM2835::gpio_fsel( &Device::BCM2835::RPI_GPIO_P1_11,
                                &Device::BCM2835::BCM2835_GPIO_FSEL_OUTP);
                                
                                
    $self->{config} = { baud_rate     => $arg->{baud_rate} || 45,
                        character_set => $arg->{character_set} || 'US',
                        ltrs_or_figs  => 'LTRS', # Default assumption will be LTRS
                        max_columns   => 80,
                        delay         => 25,  # 22 ms didn't track quite right.
                      };                                


    $self->{config}{bit_length_ms} = 1/$self->{config}{baud_rate} * 1000;
    $self->{config}{tx_transform}  = &set_transform_table($self->{config}{character_set});

    $self->{rx_ltrs_charset} = &baudot_to_ltrs();
    $self->{rx_figs_charset} = &baudot_to_figs();

}



sub read_line {
    my ($self, $arg) = @_;

    my $line;
    my @bits;

#    print "in read_line\n";

    for (;;) {
        my $level = 1 - Device::BCM2835::gpio_lev(&Device::BCM2835::RPI_GPIO_P1_15);
         
        if ($level == 0) { # Start of a character
 #           print "woot!\n";
           
            Device::BCM2835::delay( $self->{config}{delay} );
    
            $bits[0] = 1 - Device::BCM2835::gpio_lev(&Device::BCM2835::RPI_GPIO_P1_15);
            Device::BCM2835::delay( $self->{config}{delay} );    
    
            $bits[1] = 1 - Device::BCM2835::gpio_lev(&Device::BCM2835::RPI_GPIO_P1_15);
            Device::BCM2835::delay( $self->{config}{delay} );    
    
            $bits[2] = 1 - Device::BCM2835::gpio_lev(&Device::BCM2835::RPI_GPIO_P1_15);
            Device::BCM2835::delay( $self->{config}{delay} );    
       
            $bits[3] = 1 - Device::BCM2835::gpio_lev(&Device::BCM2835::RPI_GPIO_P1_15);
            Device::BCM2835::delay( $self->{config}{delay} );    
    
            $bits[4] = 1 - Device::BCM2835::gpio_lev(&Device::BCM2835::RPI_GPIO_P1_15);
    
            # I guess we don't care about reading the stop bits.
            Device::BCM2835::delay($self->{config}{delay});
            Device::BCM2835::delay($self->{config}{delay} / 2);
    
            my $baudot_word = join('', @bits);
            $arg->{debug} && print "($baudot_word): ";
            
            if ($self->{rx_ltrs_charset}{$baudot_word} eq 'LTRS' and $self->{config}{ltrs_or_figs} eq 'FIGS') {
                # We're changing character sets.
                $self->{config}{ltrs_or_figs} = 'LTRS';
                next;
            }
            elsif ($self->{rx_ltrs_charset}{$baudot_word} eq 'FIGS' and $self->{config}{ltrs_or_figs} eq 'LTRS') {
                # We're changing character sets.
                $self->{config}{ltrs_or_figs} = 'FIGS';
                next;
            }
            
            if ($self->{rx_ltrs_charset}{$baudot_word} eq ' ' and $self->{config}{ltrs_or_figs} eq 'FIGS') {
                # A space character auto-sets the TTY back to LTRS, but does not transmit this
                # so we must reset ourselves.
                $self->{config}{ltrs_or_figs} = 'LTRS';
            }            
            
            
            my $next_char;
            if ($self->{config}{ltrs_or_figs} eq 'LTRS') {
                $next_char = $self->{rx_ltrs_charset}{$baudot_word};
            }
            else {
                $next_char = $self->{rx_figs_charset}{$baudot_word};
            }
            
#            print "next_char: --$next_char--\n";
            
            
            $line .= $next_char;
            if ($next_char eq "\n") {
            
                return ($line =~ /\n/) ? $line : "$line\n";
            }
        }
    }



}


sub teleprint {
    my ($self, $print_text) = @_;

#     print "in teletprint()\n";

    $print_text = uc($print_text);

    $print_text =~ s/\n/\r\n/g; # Replace newlines (10) with a CR/LF pair.

    foreach my $x (0..length($print_text)-1) {
        my $char_to_print = substr($print_text, $x, 1);
       
        my $baudot_word = $self->{config}{tx_transform}{$char_to_print}{baudot} || &transform_custom_character( $char_to_print ) || '';

#        print "char_to_print: --$char_to_print-- baudot_word: --$baudot_word--\n";

        my $l_or_f = $self->{config}{tx_transform}{(substr($print_text, $x, 1))}{l_or_f};
        
#        print "We are in $config->{ltrs_or_figs} case, need to be in: $l_or_f case.\n";

        # Do we need to change to LTRS or FIGS?
        #
        if ($l_or_f and $l_or_f ne $self->{config}{ltrs_or_figs}) { # Need to change!

            my $baudot_change_state;
            if ($l_or_f eq 'LTRS') { # Need to change to FIGS
                $self->{config}{ltrs_or_figs} = 'LTRS';
            }
            else { # Need to change to LTRS state
                $self->{config}{ltrs_or_figs} = 'FIGS';
            }
            $baudot_change_state = &transform_custom_character( $self->{config}{ltrs_or_figs} );
            
#            print "Changing to $self->{config}{ltrs_or_figs} state with: $baudot_change_state\n";
            
            $self->send_baudot_word_to_teletype(&transform_custom_character($self->{config}{ltrs_or_figs}));
        }
        elsif (ord($char_to_print) == 10 or ord($char_to_print) == 13) {
            $self->{config}{current_col} = 1;
        }
        else { # Not changing between LTRS or FIGS, sending BELL or other non-printable character, so need to increment current_col
            $self->{config}{current_col}++;
        }
        
        # Have we exceeded max_columns? If so, we need to send a CR/LF
        if ($self->{config}{current_col} > $self->{config}{max_columns}) {
            $self->send_baudot_word_to_teletype( transform_custom_character("\r") );
            $self->send_baudot_word_to_teletype( transform_custom_character("\n") );
            
            $self->{config}{current_col} = 1;
        }
        
        # print "\nx: --$x--    l_or_f: --$l_or_f--   baudot_word: --$baudot_word--  --".substr($print_text, $x, 1)."--\n";

        $self->send_baudot_word_to_teletype($baudot_word);
    }
}    



sub send_baudot_word_to_teletype {
    my ($self, $baudot_word) = @_;

#    print "in send_baudot_word_to_teletype()  baudot_word: --$baudot_word-- \n";

    # Start bit
    $self->space();
    $self->pause();

    foreach my $num (0..length($baudot_word)-1) {
        if (substr($baudot_word,$num,1) eq '1') {
            $self->mark();
        }
        else {
            $self->space();
        }

        $self->pause();
    }

    # Stop bits
    $self->mark();
    $self->pause();
    $self->mark(); # Redundant, I know.
    $self->pause();
}        




sub mark {
    my $self = shift;

    # Turn OFF
    Device::BCM2835::gpio_write(&Device::BCM2835::RPI_GPIO_P1_11, 0);
    # print '0';
}

sub space {
    my $self = shift;

    # Turn ON
    Device::BCM2835::gpio_write(&Device::BCM2835::RPI_GPIO_P1_11, 1);
    # print '1';;
}



sub pause {
    my $self = shift;

    my $pause_length = shift || $self->{config}{bit_length_ms};

#    print "(pausing $pause_length ms)\n";

    Device::BCM2835::delay( $pause_length ); # Milliseconds
}


sub transform_custom_character {
    my $char = shift;
    
#    print "Hi $char, You are a: ".ord($char)."\n";

    if ($char eq 'LTRS') {
        return '11111';
    }
    elsif ($char eq 'FIGS') {
        return '11011';
    }    

    if (ord($char) == 10) { # LF
        return '01000';
    }        
    elsif (ord($char) == 13) { # CR
        return '00010';
    }

    if (ord($char) == 7) { # BELL!
        print "BELL!\n";
        
#               '11111' => "LTRS",
#               '11011' => "FIGS",
        
        return '10100';
    }


}

sub set_transform_table {
    my $char_set = shift || 'US',
 
    # It looks like the following character sets exist:
    # Murray, ASCII over AMTOR, ITA 2, Weather, Fraction, US.
    # My model 15 is of type Fraction, and my model 28 is
    # US, so those are the only two I've tinkered with.

    my $transform = { 'A' => { baudot => '11000',
                               l_or_f => 'LTRS',
                             },
                      'B' => { baudot => '10011',
                               l_or_f => 'LTRS',
                             },                      
                      'C' => { baudot => '01110',
                               l_or_f => 'LTRS',
                             },                      
                      'D' => { baudot => '10010',
                               l_or_f => 'LTRS',
                             },                      
                      'E' => { baudot => '10000',
                               l_or_f => 'LTRS',
                             },                      
                      'F' => { baudot => '10110',
                               l_or_f => 'LTRS',
                             },                      
                      'G' => { baudot => '01011',
                               l_or_f => 'LTRS',
                             },                      
                      'H' => { baudot => '00101',
                               l_or_f => 'LTRS',
                             },                      
                      'I' => { baudot => '01100',
                               l_or_f => 'LTRS',
                             },                      
                      'J' => { baudot => '11010',
                               l_or_f => 'LTRS',
                             },                      
                      'K' => { baudot => '11110',
                               l_or_f => 'LTRS',
                             },                      
                      'L' => { baudot => '01001',
                               l_or_f => 'LTRS',
                             },                      
                      'M' => { baudot => '00111',
                               l_or_f => 'LTRS',
                             },                      
                      'N' => { baudot => '00110',
                               l_or_f => 'LTRS',
                             },                      
                      'O' => { baudot => '00011',
                               l_or_f => 'LTRS',
                             },                      
                      'P' => { baudot => '01101',
                               l_or_f => 'LTRS',
                             },                      
                      'Q' => { baudot => '11101',
                               l_or_f => 'LTRS',
                             },                      
                      'R' => { baudot => '01010',
                               l_or_f => 'LTRS',
                             },                      
                      'S' => { baudot => '10100',
                               l_or_f => 'LTRS',
                             },                      
                      'T' => { baudot => '00001',
                               l_or_f => 'LTRS',
                             },                      
                      'U' => { baudot => '11100',
                               l_or_f => 'LTRS',
                             },                      
                      'V' => { baudot => '01111',
                               l_or_f => 'LTRS',
                             },                      
                      'W' => { baudot => '11001',
                               l_or_f => 'LTRS',
                             },                      
                      'X' => { baudot => '10111',
                               l_or_f => 'LTRS',
                             },                      
                      'Y' => { baudot => '10101',
                               l_or_f => 'LTRS',
                             },                      
                      'Z' => { baudot => '10001',
                               l_or_f => 'LTRS',
                             },                      

                      ' ' => { baudot => '00100',
                               l_or_f => 'LTRS',
                             },                      
                      '0' => { baudot => '01101',
                               l_or_f => 'FIGS',
                             },                      
                      '1' => { baudot => '11101',
                               l_or_f => 'FIGS',
                             },                      
                      '2' => { baudot => '11001',
                               l_or_f => 'FIGS',
                             },                      
                      '3' => { baudot => '10000',
                               l_or_f => 'FIGS',
                             },                      
                      '4' => { baudot => '01010',
                               l_or_f => 'FIGS',
                             },                      
                      '5' => { baudot => '00001',
                               l_or_f => 'FIGS',
                             },                      
                      '6' => { baudot => '10101',
                               l_or_f => 'FIGS',
                             },                      
                      '7' => { baudot => '11100',
                               l_or_f => 'FIGS',
                             },                      
                      '8' => { baudot => '01100',
                               l_or_f => 'FIGS',
                             },                      
                      '9' => { baudot => '00011',
                               l_or_f => 'FIGS',
                             },

                    };

    if ($char_set eq 'US') {
        $transform->{'-'}{baudot} = '11000';
        $transform->{'-'}{l_or_f} = 'FIGS';

#        $transform->{'BELL'} = '10100',  # BELL! fixme


        $transform->{'$'}{baudot} = '10010';
        $transform->{'$'}{l_or_f} = 'FIGS';
        $transform->{'!'}{baudot} = '10110';
        $transform->{'!'}{l_or_f} = 'FIGS';
        $transform->{'&'}{baudot} = '01011';
        $transform->{'&'}{l_or_f} = 'FIGS';
        $transform->{'#'}{baudot} = '00101';
        $transform->{'#'}{l_or_f} = 'FIGS';
        $transform->{"'"}{baudot} = '11010';
        $transform->{"'"}{l_or_f} = 'FIGS';
        $transform->{'('}{baudot} = '11110';
        $transform->{'('}{l_or_f} = 'FIGS';
        $transform->{')'}{baudot} = '01001';
        $transform->{')'}{l_or_f} = 'FIGS';
        $transform->{'"'}{baudot} = '10001';
        $transform->{'"'}{l_or_f} = 'FIGS';
        $transform->{'/'}{baudot} = '10111';
        $transform->{'/'}{l_or_f} = 'FIGS';
        $transform->{':'}{baudot} = '01110';
        $transform->{':'}{l_or_f} = 'FIGS';
        $transform->{';'}{baudot} = '01111';
        $transform->{';'}{l_or_f} = 'FIGS';
        $transform->{'?'}{baudot} = '10011';
        $transform->{'?'}{l_or_f} = 'FIGS';
        $transform->{','}{baudot} = '11010'; # was:  00110
        $transform->{','}{l_or_f} = 'FIGS';
        $transform->{'.'}{baudot} = '00111';
        $transform->{'.'}{l_or_f} = 'FIGS';
    }


    return $transform;
}
















sub baudot_to_ltrs {
    return ( { '11000' => 'A',
               '10011' => 'B',
               '01110' => 'C',
               '10010' => 'D',
               '10000' => 'E',
               '10110' => 'F',
               '01011' => 'G',
               '00101' => 'H',
               '01100' => 'I',
               '11010' => 'J',
               '11110' => 'K',
               '01001' => 'L',
               '00111' => 'M',
               '00110' => 'N',
               '00011' => 'O',
               '01101' => 'P',
               '11101' => 'Q',
               '01010' => 'R',
               '10100' => 'S',
               '00001' => 'T',
               '11100' => 'U',
               '01111' => 'V',
               '11001' => 'W',
               '10111' => 'X',
               '10101' => 'Y',
               '10001' => 'Z',
               '00100' => ' ',
               '00010' => "\n",
               '01000' => "\n",
               '11111' => "LTRS",
               '11011' => "FIGS",
              }
            );
}

sub baudot_to_figs {
    return ( { '11000' => '-',
               '10011' => '(5/8)',
               '01110' => '(W-R-U)',
               '10010' => '$',
               '10000' => '3',
               '10110' => '(1/4)',
               '01011' => '&',
               '00101' => '(stop)',
               '01100' => '8',
               '11010' => ',',
               '11110' => '(1/2)',
               '01001' => '(3/4)',
               '00111' => '.',
               '00110' => '\\',
               '00011' => '9',
               '01101' => '0',
               '11101' => '1',
               '01010' => '4',
               '10100' => '(BELL)',
               '00001' => '5',
               '11100' => '7',
               '01111' => '(3/8)',
               '11001' => '2',
               '10111' => '/',
               '10101' => '6',
               '10001' => '"',
               '00100' => ' ',
               '00010' => "\n",
               '01000' => "\n",
               '11111' => "LTRS",
               '11011' => "FIGS",
              }
            );
}        



return 1;



