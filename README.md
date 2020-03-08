# SDTStateMachine

# Installation

download sby loaderpack https://www.undertow.club/downloads/sby-loaderpack.4591/
extract the sby_loader_pack zip file

download Pim_gd's DialogueActions https://www.undertow.club/threads/pim_gds-mods-dialogueactions-v4-08-15-jan-2017.5889/
save SDTDialogueActions swf file in sby_loader_pack_11_545d\Loader5.45\Mods\$INIT$\
add SDTDialogueActionsv4.08.swf to the bottom of sby_loader_pack_11_545d\Loader5.45\Mods\$INIT$\Mods.txt

download MoreTriggers https://www.undertow.club/downloads/moretriggers.2840/
extract the MoreTriggers zip file into sby_loader_pack_11_545d\Loader5.45\Mods\$INIT$\
add MoreTriggers v2.2/MoreTriggersv2.2.mod to the bottom of sby_loader_pack_11_545d\Loader5.45\Mods\$INIT$\Mods.txt

download HuniePop Audio Triggers https://www.undertow.club/downloads/huniepop-audio-triggers.2885/
extract the HuniePop Audio Triggers zip file into sby_loader_pack_11_545d\Loader5.45\Mods\$INIT$\
add HuniePopAudioTriggers v1.11/HuniePopAudioTriggersv1.11.mod to the bottom of sby_loader_pack_11_545d\Loader5.45\Mods\$INIT$\Mods.txt

download zip of SDTStateMachine https://github.com/sdoibanfwae/SDTStateMachine (or use git clone if you know how)
from SDTStateMachine, put the statemachine folder into sby_loader_pack_11_545d\Loader5.45\Mods\$INIT$\
add statemachine/statemachine.swf to the bottom of sby_loader_pack_11_545d\Loader5.45\Mods\$INIT$\Mods.txt
from SDTStateMachine, put the StateMachineExample1 into sby_loader_pack_11_545d\Loader5.45\Mods\
add StateMachineExample1:StateMachineExample1 to sby_loader_pack_11_545d\Loader5.45\Mods\CharacterFolders.txt

now run sby_loader_pack_11_545d/play SDT Loader
wait for SDT to finish loading all the mods
open the bottom menu (press Y on your keyboard)
click the choose character button on the left side of the menu
click on StateMachineExample1 (probably at the end, the thumbnail is a picture of Zelda)
enjoy!

# Writing Dialogs

Check the example for how to use it. The dialog uses a trigger to load the config JSON txt file. Use The JSON Validator to verify that your JSON is correctly formatted.

You load the JSON txt file with [SMLOADCONFIG_StateMachine1] where StateMachine1 is the filename (.txt is appended automatically).

Define your variables with cutoffs (and sometimes you'll want a min and max). Special variables are vigour, depth, speed, and hispleasure. These variables are pulled from other sources. You can modify the value of hispleasure, but you cannot modify the values for the other special variables. Any other variables (like herpleasure or streak) you will have to change the value of yourself by using effects in your states.

Once your variables are defined, you can use the cutoff names as requirements in your states. Only 1 state will be active at a time, if the requirements are met for multiple states then only the best match will be selected.

When a state is triggered, the state machine calls a line of dialog with the name of the state. So if you have a state like
```
"rough": {
  "requirements": {
    "depth": ["verydeep", "hilt"],
    "speed": ["fast", "veryfast"],
    "herpleasure": ["none", "low", "high"]
  },
  "chances": 2,
  "actions": ["[ARMS_HIS_LEGS][SETVAR_da.breathPercentage_0]"],
  "effects": {
    "herpleasure": 6,
    "hispleasure": 5,
    "streak": 5
  }
}
```
Then, let's say the state changes from moving to rough, state machine will call dialog lines for rough, now_rough, and moving_to_rough. It will also continue to call the rough dialog (but not now_rough or moving_to_rough) while the state is maintained, and the chances property controls how often it gets called repeatedly.

Actions is an array of strings, each string is a line of dialog to execute when the state gets triggered (and retriggered, depending on the chances). Only 1 action is played each time the state is triggered, but an action can have as much dialog text in it as you want.

Effects is a list of variables to add to. If you want to subtract, then use a negative number.

Variables get "pseudo-states", look at the example at like depth_hilt, depth_verydeep, speed_veryfast, and speed_fast. All variables get lines of dialog called for them, but putting them inside the states list allows you to add properties, actions, and effects for them. Still it's better to use real states instead of pseudo-states, because you can only be in one state at a time, but pseudo-states can overlap and be triggered very often.

States (and pseudo-states from variables) also output variables you can use in the dialog. sm_statename_duration is how long the state has been active (this does not get wiped until the state is activated again). sm_statename_times is how many times the state has been entered. sm_statename_totaltime is how many seconds the state has been active in total.

The interrupt property is still an experimental value, it kind of works but use it very sparingly. Interruptable doesn't work yet so currently everything is interruptable.
