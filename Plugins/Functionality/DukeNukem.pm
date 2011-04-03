#!/usr/bin/perl

use utf8;
use locale;

use Modern::Perl;

package Duke;

use Test::More;

my @duke3D = (
    "AAAAAAAAAAAAAAAAAAAAAAAAAAAAAHHHHHHHHHHHHHHHHHHHHHHHHHHHH!!!!!!!!!!!!!!!!!!!!!!!!!!!!",
    "Ah.. much better!",
    "Bitch'in'!",
    "Blow it out your ass!",
    "Born to be wiiiiiiild...",
    "Come get some!",
    "Come on!",
    "Damn!",
    "Damn, I'm good!",
    "Damn, those alien bastards are gonna pay for shooting up my ride.",
    "Damn, you're ugly.",
    "Damn... I'm looking good!",
    "Damn....",
    "Die, you son of a bitch!",
    "Eat shit and die.",
    "Get away from her, you bitch!",
    "Get back to work, you slacker!",
    "Get that crap outta here!",
    "Go ahead, make my day.",
    "Gonna rip you a new one.",
    "Groovy!",
    "Guess again, freakshow. I'm coming back to town, and the last thing that's gonna go through your mind before you die... is my size- 13 boot!",
    "Hail to the king, baby!",
    "Heh, heh, heh... what a mess!",
    "Hmm, I needed that!",
    "Hmm, don't have time to play with myself.",
    "Hmm, that's one \"Doomed\" Space Marine.",
    "Holy cow!",
    "Holy shit!",
    "I ain't afraid of no quake!",
    "I like a good cigar...and a bad woman...",
    "I'll rip your head off and shit down your neck.",
    "I'm gonna get medieval on your asses!",
    "I'm gonna kick your ass, bitch!",
    "I'm gonna put this smack dab on your ass!",
    "It's down to you and me, you one-eyed freak!",
    "It's time to abort your whole freaking species!",
    "It's time to kick ass and chew bubble gum... and I'm all outta gum.",
    "Let God sort 'em out!",
    "Let's rock!",
    "Looks like cleanup on aisle four.",
    "Lucky son of a bitch.",
    "Mess with the best, you will die like the rest",
    "My boot, your face; the perfect couple.",
    "My name is Duke Nukem - and I'm coming to get the rest of you alien bastards!",
    "No way I'm eating this shit!",
    "Nobody steals our chicks... and lives!",
    "Now this is a force to be reckoned with!",
    "Nuke 'em 'till they glow, then shoot 'em in the dark!",
    "Oh...your ass is grass and I've got the weed-whacker.",
    "Ooh, that's gotta hurt.",
    "See you in Hell!",
    "Shake it, baby!",
    "Shit happens.",
    "Sometimes I even amaze myself.",
    "Staying alive, staying alive, la.",
    "Suck it down!",
    "Terminated!",
    "That's gonna leave a mark!",
    "This is KTIT, K-Tit! Playing the breast- uhh, the best tunes in town.",
    "This really pisses me off!",
    "We meet again, Doctor Jones!",
    "What are you waitin' for? Christmas?",
    "What are you? Some bottom-feeding, scum-sucking algae eater?",
    "Where is it?",
    "Who wants some?",
    "Wohoo!",
    "Yeah, piece of cake!",
    "Yippie ka-yay, motherf***er!",
    "You guys suck!",
    "You wanna dance?",
    "You're an inspiration for birth control.",
    "Your face, your ass, what's the difference?",
);

my @dnf = (
    "Allright, time for my reward!",
    "Coochi-Coochi...",
    "Damn it, why do they always take the hot ones?",
    "Damn, those alien bastards drink of my beer",
    "Duke's in a bad, bad mood.",
    "Girl: What about the game Duke? Was it any good? Duke: Yeah, but after 12 fucking years it should be!",
    "Hail to the King, baby!",
    "Hell, I'd still hit it.",
    "I guess pigs CAN fly!",
    "I was born to rock the world!",
    "I'm from Las Vegas, and I say: kill them all.",
    "I'm gonna rip your eye out and piss on your brain, you alien dirtbag!",
    "I'm lookin' for some alien toilet to park my bricks... Who's first?",
    "I've got balls of steel.",
    "Looks like those alien bastards drank all my beer.",
    "My job is to kick ass, not make small talk.",
    "Not my babes! Not in my town! You alien motherfuckers are gonna pay for this!",
    "One in the hand is worth two in the bush.",
    "Power armor is for pussies!",
    "Rest in pieces.",
    "Right in the Jewels.",
    "Suck it down!",
    "Take your pills... er... vitamins every day and you might grow up to be as awesome as me.",
    "This is taking forever.",
    "Time to stop pissing around and get this big guy back in the action.",
    "Whaddya think I am, a chimpanzee?",
    "What? Did you think I was gone forever?",
    "You wanna touch it, don't you?",
);

my @quotes = (@duke3D, @dnf);

sub random_quote
{
    return @quotes[int rand @quotes];
}

sub dnf_quote
{
    return @dnf[int rand @dnf];
}

sub duke3D_quote
{
    return @duke3D[int rand @duke3D];
}

1;

