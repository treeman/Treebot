#!/usr/bin/perl

use Modern::Perl;

our %mi1 = (
    "This is the END for you, you gutter-crawling cur!" =>
    "And I've got a little TIP for you, get the POINT?",

    "Soon you'll be wearing my sword like a shish kebab!" =>
    "First you better stop waiving it like a feather-duster.",

    "My handkerchief will wipe up your blood!" =>
    "So you got that job as janitor, after all.",

    "People fall at my feet when they see me coming." =>
    "Even BEFORE they smell your breath?",

    "I once owned a dog that was smarter then you." =>
    "He must have taught you everything you know.",

    "You make me want to puke." =>
    "You make me think somebody already did.",

    "Nobody's ever drawn blood from me and nobody ever will." =>
    "You run THAT fast?",

    "You fight like a dairy farmer." =>
    "How appropriate. You fight like a cow.",

    "I got this scar on my face during a mighty struggle!" =>
    "I hope now you've learned to stop picking your nose.",

    "Have you stopped wearing diapers yet?" =>
    "Why, did you want to borrow one?",

    "I've heard you were a contemptible sneak." =>
    "Too bad no one's ever heard of YOU at all.",

    "You're no match for my brains, you poor fool." =>
    "I'd be in real trouble if you ever used them.",

    "You have the manners of a beggar." =>
    "I wanted to make sure you'd feel comfortable with me.",

    "I'm not going to take your insolence sitting down!" =>
    "Your hemorrhoids are flaring up again, eh?",

    "There are no words for how disgusting you are." =>
    "Yes there are. You just never learned them.",

    "I've spoken with apes more polite then you." =>
    "I'm glad to hear you attended your family reunion.",
);

our %sword_master = (
    "I've got a long, sharp lesson for you you to learn today." =>
    "And I've got a little TIP for you. Get the POINT?",

    "My tongue is sharper then any sword." =>
    "First you better stop waving it like a feather-duster.",

    "My name is feared in every dirty corner of this island!" =>
    "So you got that job as janitor, after all.",

    "My wisest enemies run away at the first sight of me!" =>
    "Even BEFORE they smell your breath?",

    "Only once have I met such a coward!" =>
    "He must have taught you everything you know.",

    "If your brother's like you, better to marry a pig." =>
    "You make me think somebody already did.",

    "No one will ever catch ME fighting as badly as you do." =>
    "You run THAT fast?",

    "I will milk every drop of blood from your body!" =>
    "How appropriate. You fight like a cow.",

    "My last fight ended with my hands covered with blood." =>
    "I hope now you've learned to stop picking your nose.",

    "I hope you have a boat ready for a quick escape." =>
    "Why, did you want to borrow one?",

    "My sword is famous all over the Caribbean!" =>
    "Too bad no one's ever heard of YOU at all.",

    "I've got the courage and skill of a master swordsman!" =>
    "I'd be in real trouble if you ever used them.",

    "Every word you say to me is stupid." =>
    "I wanted to make sure you'd feel comfortable with me.",

    "You are a pain in the backside, sir!" =>
    "Your hemorrhoids are flaring up again, eh?",

    "There are no clever moves that can help you now." =>
    "Yes there are. You just never learned them.",

    "Now I know what filth and stupidity really are." =>
    "I'm glad to hear you attended your family reunion.",

    "I usually see people like you passed-out on tavern floors." =>
    "Even BEFORE they smell your breath? ",
);

our %mi3 = (
    "Every enemy I have met, I've annihilated!" =>
    "With your breath, I'm sure they all suffocated.",

    "You're as repulsive as a monkey in a negligee!" =>
    "I look that much like your fiancée?",

    "Killing you would be justifiable homicide!" =>
    "Then killing you must be justifiable fungicide.",

    "You're the ugliest monster ever created!" =>
    "If you don't count all the ones you've dated.",

    "I'll skewer you like a sow at a buffet!" =>
    "When I'm done with you, you'll be a boneless filet.",

    "Would you like to be buried, or cremated?" =>
    "With you around, I'd rather be fumigated.",

    "Coming face to face with me must leave you petrified!" =>
    "Is that your face? I thought it was your backside.",

    "When your father first saw you, he must have been mortified!" =>
    "At least mine can be identified.",

    "You can't match my witty repartee!" =>
    "I could, if you would use some breath spray.",

    "I have never seen such clumsy swordplay!" =>
    "You would have, but you were always running away.",

    "En Garde! Touché!" =>
    "Oh, that is so cliché.",

    "Throughout the Caribbean, my great deeds are celebrated!" =>
    "Too bad they're all fabricated.",

    "I can't rest 'til' you've been exterminated!" =>
    "Then perhaps you should switch to decaffeinated.",

    "I'll leave you devastated, mutilated, and perforated!" =>
    "Your odor alone makes me aggravated, agitated, and infuriated",

    "Heaven preserve me! You look like something that's died!" =>
    "The only way you'll be preserved is in formaldehyde",

    "I'll hound you night and day!" =>
    "Then be a good dog, Sit! Stay!",
);

our %captain_rottingham = (
    "My attacks have left entire islands depopulated!" =>
    "With your breath, I'm sure they all suffocated.",

    "You have the sex appeal of a shar-pei!" =>
    "I look that much like your fiancée?",

    "When I'm done, your body will be rotted and putrefied!" =>
    "Then killing you must be justifiable fungicide.",

    "Your looks would make pigs nauseated!" =>
    "If you don't count all the ones you've dated.",

    "Your lips look like they belong on the catch of the day!" =>
    "When I'm done with you, you'll be a boneless filet.",

    "I give you a choice. You can be gutted, or decapitated!" =>
    "With you around, I'd rather be fumigated.",

    "Never before have I faced someone so sissified!" =>
    "Is that your face? I thought it was your backside.",

    "You're a disgrace to your species, you're so undignified!" =>
    "At least mine can be identified.",

    "Nothing can stop me from blowing you away!" =>
    "I could, if you would use some breath spray.",

    "I have never lost a melee!" =>
    "You would have, but you were always running away.",

    "Your mother wears a toupee!" =>
    "Oh, that is so cliché.",

    "My skills with a sword are highly venerated!" =>
    "Too bad they're all fabricated.",

    "Your stench would make an outhouse cleaner irritated!" =>
    "Then perhaps you should switch to decaffeinated.",

    "I can't tell which of my traits have you the most intimidated!" =>
    "Your odor alone makes me aggravated, agitated, and infuriated",

    "Nothing on this earth can save your sorry hide!" =>
    "The only way you'll be preserved is in formaldehyde",

    "You'll find I'm dogged and relentless to my prey!" =>
    "Then be a good dog, Sit! Stay!",
);

our %mi4 = (
    "Today, by myself, twelve people I've beaten." =>
    "From the size of your gut I'd guess they were eaten.",

    "I've got muscles in places you've never even heard of." =>
    "It's too bad none of them are in your arms.",

    "Give up now, or I'll crush you like a grape!" =>
    "I would if it would stop your WINE-ING.",

    "My ninety-eight year old grandmother has bigger arms than you!" =>
    "Yeah, but we both got better bladder control than you do.",

    "I'm going to put your arm in a sling!" =>
    "Why, ya studying to be a nurse?",

    "My stupefying strength will shatter your ulna into a million pieces!" =>
    "I'm surprised you can count that high!",

    "Hey, look over there!" =>
    "Yeah, yeah I know: it's a three headed monkey.",

    "Your knuckles I'll grind to a splintery paste." =>
    "I thought that the been dip had a strange taste.",

    "Your arms are no bigger than fleas that I've met!" =>
    "So THAT'S why you're scratching. I'd go see a vet.",

    "People consider my fists lethal weapons!" =>
    "Sadly, your breath should be equally reckoned.",

    "Only once have I met such a coward!" =>
    "He must have taught you everything you know.",

    "You're the ugliest creature I've ever seen in my life." =>
    "I'm shocked that you've never gazed at your wife.",

    "My forearms have been mistaken for tree trunks!" =>
    "An over-the-counter defoliant could help with that problem.",

    "I've out-wrestled octopi with these arms!" =>
    "I'm sure that spineless creatures everywhere are humbled by your might.",

    "Do I see quivers of agony dance on your lip?" =>
    "It's laughter that's caused by your feathery grip.",
);

