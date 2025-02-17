extensions [ table ]
globals [
  grid-spacing
  tx
  ty

    ;; Adjust the minimum and maximum coordinates to include (0, 0)
  minimum-pxcor
  maximum-pxcor
  minimum-pycor
  maximum-pycor

  num-round

  num-cooperate
  num-defect
  num-unforgiving
  num-rl
  num-tit-for-tat
  num-computers
  num-random

  num-cooperate-games
  num-defect-games
  num-unforgiving-games
  num-rl-games
  num-random-games
  num-tit-for-tat-games

  cooperate-score
  defect-score
  unforgiving-score
  rl-score
  random-score
  tit-for-tat-score
]

breed [computers computer]

computers-own [
  score
  strategy
  defect-now?
  partner-defected?
  partnered?
  partner
  partner-history
  ;for RL:
  current-action
  prev-action
  original-action
  prev-reward
  current-state
  prev-state
  q-table
  v-table
]

;;;;;;;;;;;;;;;;;;;;;;
;;;Setup Procedures;;;
;;;;;;;;;;;;;;;;;;;;;;

to setup
  clear-all
  calculate-world-size
  resize-world minimum-pxcor maximum-pxcor minimum-pycor maximum-pycor
  setup-computers
  reset-ticks
  set grid-spacing 4
  drawGrid
  set num-round 0
  output-print (word "round,cooperate-score,defect-score,tit-for-tat-score,unforgiving-score, random-score, qlearning-score")
end

to calculate-world-size
  ;; Calculate the side length of the square based on the number of turtles
  let side-length sqrt num-turtles
  set side-length side-length * 4
  ;; Adjust the minimum and maximum coordinates to include (0, 0)
  set minimum-pxcor (- side-length / 2)
  set maximum-pxcor (side-length / 2)
  set minimum-pycor (- side-length / 2)
  set maximum-pycor (side-length / 2)
end

to setup-computers
  ;;set-default-shape computers "computer"
  make-computers
  setup-common-vars
end

to drawGrid
cro 1 [
    draw-hatches
    home
    pendown
    set color white
    set pen-size 1
    die
  ]
end

to adjust-coord
  set tx tx + 4
 ;;if we reach x edge, go to the next y
  if tx > max-pxcor [
    set tx min-pxcor + 1.9
    set ty ty - 4
  ]
end

to draw-hatches
  set heading 0
  set pen-size .6
  set color white
  set xcor min-pxcor
  repeat ((max-pxcor - min-pxcor) / grid-spacing) [
    pd set ycor min-pycor
    fd (max-pycor - min-pycor)
    pu
    set xcor (xcor + grid-spacing)
  ]

  set heading 90
  pu
  set ycor min-pycor
  repeat ((max-pycor - min-pycor) / grid-spacing) [
    set xcor min-pxcor
    pd
    fd (max-pxcor - min-pxcor)
    pu
    set ycor (ycor + grid-spacing)
  ]
end

to make-computers
  ;; initialize the position at the top left-hand corner
  set tx min-pxcor + 1.9
  set ty max-pycor - 1.9

  ;;reset counts to prevent any problem
  set num-cooperate 0
  set num-defect 0
  set num-unforgiving 0
  set num-random 0
  set num-rl 0
  set num-tit-for-tat 0

  ;;construct the list of strategies so we can randomly assign one of them to a turtle
  let strategies []
  if always-cooperate-player? [ set strategies lput "play-always-cooperate" strategies ]
  if always-defect-player? [ set strategies lput "play-always-defect" strategies ]
  if unforgiving-player? [ set strategies lput "play-unforgiving" strategies ]
  if tit-for-tat-player? [ set strategies lput "play-tit-for-tat" strategies ]
  if random-player? [ set strategies lput "play-random" strategies ]
  if q-learning-player? [ set strategies lput "play-rl" strategies ]

  create-computers num-turtles [
    ;;that's where we assign a strategy
    set strategy one-of strategies

    if strategy = "play-always-cooperate" [ set num-cooperate num-cooperate + 1 set color yellow ]
    if strategy = "play-always-defect" [ set num-defect num-defect + 1 set color gray ]
    if strategy = "play-unforgiving" [ set num-unforgiving num-unforgiving + 1 set color red ]
    if strategy = "play-tit-for-tat" [ set num-tit-for-tat num-tit-for-tat + 1 set color lime ]
    if strategy = "play-random" [ set num-random num-random + 1 set color violet ]
    if strategy = "play-rl" [ set num-rl num-rl + 1 set color pink ]

    setxy tx ty
    adjust-coord
  ]
end

to setup-common-vars
  ask computers [
   set shape "person"
   set score 0
   set partnered? false
   set partner nobody
   set size 3
   set prev-action one-of [ 0 1 ]
   set original-action prev-action
   set prev-reward 0
    set prev-state []
   set current-state []
   let state-action table:make
    table:put state-action [] [0 0]
   set q-table state-action
   let qt-vals table:make
    table:put qt-vals [] 0
   set v-table  qt-vals
  ]
  setup-history-lists
end

to setup-history-lists
  set num-computers count computers
  let default-history table:make
  ;;repeat num-computers [ set default-history lput [ false false ] default-history ]
  let i 0
  while [ i < (num-computers) ] [
    table:put default-history i [ false false false false false false false false false false ]
    set i (i + 1)
  ]
  ask computers [ set partner-history default-history ]
end

;;;;;;;;;;;;;;;;;;;;;;
;;Runtime Procedures;;
;;;;;;;;;;;;;;;;;;;;;;

to go ;; clear -> partner-up -> play -> decouple
  ;;clear-last-round
  play-a-round
  prepare-next-round
  tick
end

to play-a-round
  let i 0
  while [ i < (num-computers - 1) ] [
    let computer-one computers with [ who = i ]
    let j (i + 1)
    while [ j < (num-computers) ] [
        let computer-two computers with [ who = j ]
        ask one-of computer-one [ partner-up one-of computer-two ]
        let players computers with [ partnered? ]
        ask players [ select-action ]
        ask players [ play ]
        clear-last-round
        set j (j + 1)
    ]
    set i (i + 1)
  ]
end

to partner-up [ partner-computer ] ;;turtle procedure
  if (not partnered?) [              ;;make sure still not partnered
    set partner partner-computer
    set size 5
    if partner != nobody [              ;;if successful grabbing a partner, partner up
      set partnered? true
      ask partner [
        set partnered? true
        set partner myself
        set size 5
      ]
    ]
  ]
end

to decouple
  set partnered? false
  set partner nobody
  set size 3
  set label ""
end

to play
  ;;select-action
  get-payoff
  update-history
end

to select-action ;;computer procedure
  if strategy = "random" [ act-randomly ]
  if strategy = "play-always-cooperate" [ cooperate ]
  if strategy = "play-always-defect" [ defect ]
  if strategy = "play-tit-for-tat" [ tit-for-tat ]
  if strategy = "play-unforgiving" [ unforgiving ]
  if strategy = "play-random" [ act-randomly ]
  if strategy = "play-rl" [ q-learning ]
end

to get-payoff
  set partner-defected? [defect-now?] of partner
  ifelse partner-defected? [
    ifelse defect-now? [
      set score (score + 1) set label 1
    ] [
      set score (score + 0) set label 0
    ]
  ] [
    ifelse defect-now? [
      set score (score + 5) set label 5
    ] [
      set score (score + 3) set label 3
    ]
  ]
end

to update-history
  if strategy = "play-tit-for-tat" [ tit-for-tat-history-update ]
  if strategy = "play-unforgiving" [ unforgiving-history-update ]
  if strategy = "play-rl" [ rl-history-update ]
end

to prepare-next-round
  ;;ask computers [ set label average-score ]
  do-scoring
  clear-last-round
end

to clear-last-round
  let partnered-turtles turtles with [ partnered? ]
  ask partnered-turtles [ decouple ]
end

to-report average-score
  report precision ( (score / num-computers) / (ticks + 1)) 3
end

;;;;;;;;;;;;;;;;;;;;;;
;;;;;;Strategies;;;;;;
;;;;;;;;;;;;;;;;;;;;;;

to act-randomly ; computer Procedure
  set num-random-games num-random-games + 1
  set defect-now? one-of [ true false ]
end

to cooperate ; computer Procedure
  set num-cooperate-games num-cooperate-games + 1
  set defect-now? false
end

to defect ; computer Procedure
  set num-defect-games num-defect-games + 1
  set defect-now? true
end

to tit-for-tat
  set num-tit-for-tat-games num-tit-for-tat-games + 1
  let partner-defection-hist table:get partner-history ([who] of partner)
  set partner-defected? last partner-defection-hist
  ifelse (partner-defected?)
    [set defect-now? true]
    [set defect-now? false]
end

to tit-for-tat-history-update
  let partner-defection-hist table:get partner-history ([who] of partner)
  set partner-defection-hist lput partner-defected? partner-defection-hist
  table:put partner-history ([who] of partner) partner-defection-hist
end

to unforgiving
  set num-unforgiving-games num-unforgiving-games + 1
  let partner-defection-hist table:get partner-history ([who] of partner)
  set partner-defected? member? true partner-defection-hist
  ifelse (partner-defected?)
    [set defect-now? true]
    [set defect-now? false]
end

to unforgiving-history-update
  let partner-defection-hist table:get partner-history ([who] of partner)
  set partner-defection-hist lput partner-defected? partner-defection-hist
  table:put partner-history ([who] of partner) partner-defection-hist
end

to q-learning
  set num-rl-games num-rl-games + 1
  let partner-hist table:get partner-history ([ who ] of partner)
  let cooperation-prob 0
  let i 0
  while [i < (length partner-hist - 1)] [
    if ((item i partner-hist) = false) [ set cooperation-prob cooperation-prob + 1 ]
    set i i + 1
  ]
  set cooperation-prob cooperation-prob / length partner-hist
  ;let cooperation-prob ((count filter [ ? = false ] partner-hist) / length partner-hist)
  set current-state (list (sublist partner-hist (length partner-hist - 10) (length partner-hist)) cooperation-prob)
  let partner-prev-action last partner-hist
  set prev-reward (calc-payoff prev-action partner-prev-action)
  if (not table:has-key? q-table current-state) [
    table:put q-table current-state [0 0]
    table:put v-table current-state 0
  ]
  ;q-learn
  let alpha 0.9
  let gamma 0.1
  let epsilon 0.2
  let prev-qt-vals table:get q-table prev-state
  ifelse prev-action = 0
    [ set prev-qt-vals replace-item 0 prev-qt-vals ((1.0 -  alpha) * (item 0 prev-qt-vals) + alpha * (prev-reward + gamma * (table:get v-table current-state))) ]
    [ set prev-qt-vals replace-item 1 prev-qt-vals ((1.0 -  alpha) * (item 1 prev-qt-vals) + alpha * (prev-reward + gamma * (table:get v-table current-state))) ]
  table:put q-table prev-state prev-qt-vals
  table:put v-table prev-state max prev-qt-vals
  ;policy selection
  ifelse (random-float 1 < (1 - epsilon))
    [
      ifelse ((position max(prev-qt-vals) prev-qt-vals) = 0)
        [ set current-action 0 ]
        [ set current-action 1 ]
    ]
    [ set current-action one-of [0 1] ]
  set prev-state current-state
  set prev-action current-action
  ifelse (current-action = 0)
    [ set defect-now? false ]
    [ set defect-now? true ]
end

to rl-history-update
  let partner-defection-hist table:get partner-history ([who] of partner)
  set partner-defection-hist lput partner-defected? partner-defection-hist
  table:put partner-history ([who] of partner) partner-defection-hist
end

to-report calc-payoff [self-action partner-action]
  (ifelse
    (self-action = 0 and partner-action = 0) [
      report 3
    ]
    (self-action = 0 and partner-action = 1) [
      report 0
    ]
    (self-action = 1 and partner-action = 0) [
      report 5
    ]
    ; elsecommands
    [
      report 3
  ])
end


;;;;;;;;;;;;;;;;;;;;;;
;;;;;;;;Graph;;;;;;;;;
;;;;;;;;;;;;;;;;;;;;;;
to do-scoring
  ;;set random-score  (calc-score "random" num-random)
  set cooperate-score  (calc-score "play-always-cooperate" num-cooperate)
  set defect-score  (calc-score "play-always-defect" num-defect)
  set tit-for-tat-score  (calc-score "play-tit-for-tat" num-tit-for-tat)
  set unforgiving-score  (calc-score "play-unforgiving" num-unforgiving)
  set random-score (calc-score "play-random" num-random)
  set rl-score (calc-score "play-rl" num-rl)
  set num-round (num-round + 1)
  let row (word num-round)
  ifelse num-cooperate > 0 [
    set row (word row "," (cooperate-score / num-cooperate-games))
  ] [
    set row (word row ",null")
  ]
  ifelse num-defect > 0 [
    set row (word row "," (defect-score / num-defect-games))
  ] [
    set row (word row ",null")
  ]
  ifelse num-tit-for-tat > 0 [
    set row (word row "," (tit-for-tat-score / num-tit-for-tat-games))
  ] [
    set row (word row ",null")
  ]
  ifelse num-unforgiving > 0 [
    set row (word row "," (unforgiving-score / num-unforgiving-games))
  ] [
    set row (word row ",null")
  ]
  ifelse num-random > 0 [
    set row (word row "," (random-score / num-random-games))
  ] [
    set row (word row ",null")
  ]
  ifelse num-rl > 0 [
    set row (word row "," (rl-score / num-rl-games))
  ] [
    set row (word row ",null")
  ]
  output-print (word row)
  ;output-print (word num-round "," (cooperate-score / num-cooperate-games) "," (defect-score / num-defect-games) "," (tit-for-tat-score / num-tit-for-tat-games) "," (unforgiving-score / num-unforgiving-games))
  ;;set unknown-score  (calc-score "unknown" num-unknown)
end

;; returns the total score for a strategy if any turtles exist that are playing it
to-report calc-score [strategy-type num-with-strategy]
  ifelse num-with-strategy > 0 [
    report (sum [ score ] of (turtles with [ strategy = strategy-type ]))
  ] [
    report 0
  ]
end
@#$#@#$#@
GRAPHICS-WINDOW
568
21
1109
563
-1
-1
13.0
1
10
1
1
1
0
1
1
1
-20
20
-20
20
0
0
1
ticks
30.0

BUTTON
16
36
79
69
setup
setup
NIL
1
T
OBSERVER
NIL
NIL
NIL
NIL
1

BUTTON
105
36
219
69
go repeatedly
go
T
1
T
OBSERVER
NIL
NIL
NIL
NIL
0

BUTTON
244
37
327
70
go once
go
NIL
1
T
OBSERVER
NIL
NIL
NIL
NIL
0

SWITCH
16
93
205
126
always-cooperate-player?
always-cooperate-player?
0
1
-1000

SWITCH
220
95
389
128
always-defect-player?
always-defect-player?
0
1
-1000

SWITCH
18
152
172
185
unforgiving-player?
unforgiving-player?
0
1
-1000

SWITCH
220
152
363
185
tit-for-tat-player?
tit-for-tat-player?
0
1
-1000

PLOT
25
202
399
567
Average Score
Iterations
Average Score
0.0
10.0
0.0
5.0
true
true
"" ""
PENS
"always-cooperate" 1.0 0 -1184463 true "" "if num-cooperate-games > 0 [ plot cooperate-score / (num-cooperate-games) ]"
"always-defect" 1.0 0 -7500403 true "" "if num-defect-games > 0 [ plot defect-score / (num-defect-games) ]"
"unforgiving" 1.0 0 -2674135 true "" "if num-unforgiving-games > 0 [ plot unforgiving-score / (num-unforgiving-games) ]"
"tit-for-tat" 1.0 0 -13840069 true "" "if num-tit-for-tat-games > 0 [ plot tit-for-tat-score / (num-tit-for-tat-games) ]"
"random" 1.0 0 -8630108 true "" "if num-random-games > 0 [ plot random-score / (num-random-games) ]"
"q-learning" 1.0 0 -2064490 true "" "if num-rl-games > 0 [ plot rl-score / (num-rl-games) ]"

MONITOR
416
210
520
255
cooperate score
cooperate-score / (num-cooperate-games)
3
1
11

MONITOR
416
267
498
312
defect score
defect-score / num-defect-games
17
1
11

MONITOR
415
326
526
371
unforgiving score
unforgiving-score / num-unforgiving-games
17
1
11

MONITOR
415
387
513
432
tit-for-tat score
tit-for-tat-score / num-tit-for-tat-games
17
1
11

SLIDER
353
40
525
73
num-turtles
num-turtles
4
100
100.0
1
1
NIL
HORIZONTAL

MONITOR
1125
40
1226
85
num-cooperate
num-cooperate
0
1
11

MONITOR
1124
99
1203
144
NIL
num-defect
0
1
11

MONITOR
1121
164
1229
209
NIL
num-unforgiving
17
1
11

MONITOR
1120
226
1215
271
NIL
num-tit-for-tat
17
1
11

OUTPUT
1119
298
1506
558
10

SWITCH
413
96
549
129
random-player?
random-player?
0
1
-1000

MONITOR
1261
40
1349
85
num-random
num-random
17
1
11

MONITOR
416
449
511
494
random score
random-score / num-random-games
17
1
11

SWITCH
409
148
558
181
q-learning-player?
q-learning-player?
1
1
-1000

MONITOR
414
506
517
551
q-learning score
rl-score / num-rl-games
17
1
11

MONITOR
1293
129
1350
174
NIL
num-rl
17
1
11

@#$#@#$#@
## WHAT IS IT?

This model is a round robin version of the iterated prisoner's dilemma. It is intended to explore the strategic implications that emerge when the world consists entirely of prisoner's dilemma like interactions. If you are unfamiliar with the basic concepts of the prisoner's dilemma or the iterated prisoner's dilemma, please refer to the PD BASIC, PD TWO PERSON ITERATED, and the N-PERSON ITERATED models found in the PRISONER'S DILEMMA suite.

## HOW IT WORKS

The PD TWO PERSON ITERATED model demonstrates an interesting concept: When interacting with someone over time in a prisoner's dilemma scenario, it is possible to tune your strategy to do well with theirs. Each possible strategy has unique strengths and weaknesses that appear through the course of the game. For instance, always defect does best of any against the random strategy, but poorly against itself. Tit-for-tat does poorly with the random strategy, but well with itself.

This makes it difficult to determine a single "best" strategy. One such approach to doing this is to create a world with multiple agents playing a variety of strategies in repeated prisoner's dilemma situations. This model does just that. The turtles with different strategies wander around randomly until they find another turtle to play with. (Note that each turtle remembers their last interaction with each other turtle. While some strategies don't make use of this information, other strategies do.)

Payoffs

When two turtles interact, they display their respective payoffs as labels.

Each turtle's payoff for each round will determined as follows:

```text
             | Partner's Action
  Turtle's   |
   Action    |   C       D
 ------------|-----------------
       C     |   3       0
 ------------|-----------------
       D     |   5       1
 ------------|-----------------
  (C = Cooperate, D = Defect)
```

(Note: This way of determining payoff is the opposite of how it was done in the PD BASIC model. In PD BASIC, you were awarded something bad- jail time. In this model, something good is awarded- money.)

## HOW TO USE IT

### Buttons

SETUP: Setup the world to begin playing the multi-person iterated prisoner's dilemma. The number of turtles and their strategies are determined by the slider values.

GO: Have the turtles walk around the world and interact.

GO ONCE: Same as GO except the turtles only take one step.

### Sliders

N-STRATEGY: Multiple sliders exist with the prefix N- then a strategy name (e.g., n-cooperate). Each of these determines how many turtles will be created that use the STRATEGY. Strategy descriptions are found below:

### Strategies

RANDOM - randomly cooperate or defect

COOPERATE - always cooperate

DEFECT - always defect

TIT-FOR-TAT - If an opponent cooperates on this interaction cooperate on the next interaction with them. If an opponent defects on this interaction, defect on the next interaction with them. Initially cooperate.

UNFORGIVING - Cooperate until an opponent defects once, then always defect in each interaction with them.

Q-LEARNING - Uses Q-Learning to explore, then exploit and set its action.

### Plots

AVERAGE-PAYOFF - The average payoff of each strategy in an interaction vs. the number of iterations. This is a good indicator of how well a strategy is doing relative to the maximum possible average of 5 points per interaction.

## THINGS TO NOTICE

Set all the number of player for each strategy to be equal in distribution.  For which strategy does the average-payoff seem to be highest?  Do you think this strategy is always the best to use or will there be situations where other strategy will yield a higher average-payoff?

Set the number of n-cooperate to be high, n-defects to be equivalent to that of n-cooperate, and all other players to be 0.  Which strategy will yield the higher average-payoff?

Set the number of n-tit-for-tat to be high, n-defects to be equivalent to that of n-tit-for-tat, and all other playerst to be 0.  Which strategy will yield the higher average-payoff?  What do you notice about the average-payoff for tit-for-tat players and defect players as the iterations increase?  Why do you suppose this change occurs?

Set the number n-tit-for-tat to be equal to the number of n-cooperate.  Set all other players to be 0.  Which strategy will yield the higher average-payoff?  Why do you suppose that one strategy will lead to higher or equal payoff?

## THINGS TO TRY

1. Observe the results of running the model with a variety of populations and population sizes. For example, can you get cooperate's average payoff to be higher than defect's? Can you get Tit-for-Tat's average payoff higher than cooperate's? What do these experiments suggest about an optimal strategy?

2. Currently the UNKNOWN strategy defaults to TIT-FOR-TAT. Modify the UNKOWN and UNKNOWN-HISTORY-UPDATE procedures to execute a strategy of your own creation. Test it in a variety of populations.  Analyze its strengths and weaknesses. Keep trying to improve it.

3. Relate your observations from this model to real life events. Where might you find yourself in a similar situation? How might the knowledge obtained from the model influence your actions in such a situation? Why?

## EXTENDING THE MODEL

Relative payoff table - Create a table which displays the average payoff of each strategy when interacting with each of the other strategies.

Complex strategies using lists of lists - The strategies defined here are relatively simple, some would even say naive.  Create a strategy that uses the PARTNER-HISTORY variable to store a list of history information pertaining to past interactions with each turtle.

Evolution - Create a version of this model that rewards successful strategies by allowing them to reproduce and punishes unsuccessful strategies by allowing them to die off.

Noise - Add noise that changes the action perceived from a partner with some probability, causing misperception.

Spatial Relations - Allow turtles to choose not to interact with a partner.  Allow turtles to choose to stay with a partner.

Environmental resources - include an environmental (patch) resource and incorporate it into the interactions.

## NETLOGO FEATURES

Note the use of the `to-report` keyword in the `calc-score` procedure to report a number.

Note the use of lists and turtle ID's to keep a running history of interactions in the `partner-history` turtle variable.

Note how agentsets that will be used repeatedly are stored when created and reused to increase speed.

## RELATED MODELS

PD Basic, PD Two Person Iterated, PD Basic Evolutionary

## HOW TO CITE

If you mention this model or the NetLogo software in a publication, we ask that you include the citations below.

For the model itself:

* Wilensky, U. (2002).  NetLogo Prisoner's Dilemma N-Person Iterated model.  http://ccl.northwestern.edu/netlogo/models/Prisoner'sDilemmaN-PersonIterated.  Center for Connected Learning and Computer-Based Modeling, Northwestern University, Evanston, IL.

Please cite the NetLogo software as:

* Wilensky, U. (1999). NetLogo. http://ccl.northwestern.edu/netlogo/. Center for Connected Learning and Computer-Based Modeling, Northwestern University, Evanston, IL.

## COPYRIGHT AND LICENSE

Copyright 2002 Uri Wilensky.

![CC BY-NC-SA 3.0](http://ccl.northwestern.edu/images/creativecommons/byncsa.png)

This work is licensed under the Creative Commons Attribution-NonCommercial-ShareAlike 3.0 License.  To view a copy of this license, visit https://creativecommons.org/licenses/by-nc-sa/3.0/ or send a letter to Creative Commons, 559 Nathan Abbott Way, Stanford, California 94305, USA.

Commercial licenses are also available. To inquire about commercial licenses, please contact Uri Wilensky at uri@northwestern.edu.

This model was created as part of the projects: PARTICIPATORY SIMULATIONS: NETWORK-BASED DESIGN FOR SYSTEMS LEARNING IN CLASSROOMS and/or INTEGRATED SIMULATION AND MODELING ENVIRONMENT. The project gratefully acknowledges the support of the National Science Foundation (REPP & ROLE programs) -- grant numbers REC #9814682 and REC-0126227.

<!-- 2002 -->
@#$#@#$#@
default
true
0
Polygon -7500403 true true 150 5 40 250 150 205 260 250

airplane
true
0
Polygon -7500403 true true 150 0 135 15 120 60 120 105 15 165 15 195 120 180 135 240 105 270 120 285 150 270 180 285 210 270 165 240 180 180 285 195 285 165 180 105 180 60 165 15

arrow
true
0
Polygon -7500403 true true 150 0 0 150 105 150 105 293 195 293 195 150 300 150

box
false
0
Polygon -7500403 true true 150 285 285 225 285 75 150 135
Polygon -7500403 true true 150 135 15 75 150 15 285 75
Polygon -7500403 true true 15 75 15 225 150 285 150 135
Line -16777216 false 150 285 150 135
Line -16777216 false 150 135 15 75
Line -16777216 false 150 135 285 75

bug
true
0
Circle -7500403 true true 96 182 108
Circle -7500403 true true 110 127 80
Circle -7500403 true true 110 75 80
Line -7500403 true 150 100 80 30
Line -7500403 true 150 100 220 30

butterfly
true
0
Polygon -7500403 true true 150 165 209 199 225 225 225 255 195 270 165 255 150 240
Polygon -7500403 true true 150 165 89 198 75 225 75 255 105 270 135 255 150 240
Polygon -7500403 true true 139 148 100 105 55 90 25 90 10 105 10 135 25 180 40 195 85 194 139 163
Polygon -7500403 true true 162 150 200 105 245 90 275 90 290 105 290 135 275 180 260 195 215 195 162 165
Polygon -16777216 true false 150 255 135 225 120 150 135 120 150 105 165 120 180 150 165 225
Circle -16777216 true false 135 90 30
Line -16777216 false 150 105 195 60
Line -16777216 false 150 105 105 60

car
false
0
Polygon -7500403 true true 300 180 279 164 261 144 240 135 226 132 213 106 203 84 185 63 159 50 135 50 75 60 0 150 0 165 0 225 300 225 300 180
Circle -16777216 true false 180 180 90
Circle -16777216 true false 30 180 90
Polygon -16777216 true false 162 80 132 78 134 135 209 135 194 105 189 96 180 89
Circle -7500403 true true 47 195 58
Circle -7500403 true true 195 195 58

circle
false
0
Circle -7500403 true true 0 0 300

circle 2
false
0
Circle -7500403 true true 0 0 300
Circle -16777216 true false 30 30 240

cow
false
0
Polygon -7500403 true true 200 193 197 249 179 249 177 196 166 187 140 189 93 191 78 179 72 211 49 209 48 181 37 149 25 120 25 89 45 72 103 84 179 75 198 76 252 64 272 81 293 103 285 121 255 121 242 118 224 167
Polygon -7500403 true true 73 210 86 251 62 249 48 208
Polygon -7500403 true true 25 114 16 195 9 204 23 213 25 200 39 123

cylinder
false
0
Circle -7500403 true true 0 0 300

dot
false
0
Circle -7500403 true true 90 90 120

face happy
false
0
Circle -7500403 true true 8 8 285
Circle -16777216 true false 60 75 60
Circle -16777216 true false 180 75 60
Polygon -16777216 true false 150 255 90 239 62 213 47 191 67 179 90 203 109 218 150 225 192 218 210 203 227 181 251 194 236 217 212 240

face neutral
false
0
Circle -7500403 true true 8 7 285
Circle -16777216 true false 60 75 60
Circle -16777216 true false 180 75 60
Rectangle -16777216 true false 60 195 240 225

face sad
false
0
Circle -7500403 true true 8 8 285
Circle -16777216 true false 60 75 60
Circle -16777216 true false 180 75 60
Polygon -16777216 true false 150 168 90 184 62 210 47 232 67 244 90 220 109 205 150 198 192 205 210 220 227 242 251 229 236 206 212 183

fish
false
0
Polygon -1 true false 44 131 21 87 15 86 0 120 15 150 0 180 13 214 20 212 45 166
Polygon -1 true false 135 195 119 235 95 218 76 210 46 204 60 165
Polygon -1 true false 75 45 83 77 71 103 86 114 166 78 135 60
Polygon -7500403 true true 30 136 151 77 226 81 280 119 292 146 292 160 287 170 270 195 195 210 151 212 30 166
Circle -16777216 true false 215 106 30

flag
false
0
Rectangle -7500403 true true 60 15 75 300
Polygon -7500403 true true 90 150 270 90 90 30
Line -7500403 true 75 135 90 135
Line -7500403 true 75 45 90 45

flower
false
0
Polygon -10899396 true false 135 120 165 165 180 210 180 240 150 300 165 300 195 240 195 195 165 135
Circle -7500403 true true 85 132 38
Circle -7500403 true true 130 147 38
Circle -7500403 true true 192 85 38
Circle -7500403 true true 85 40 38
Circle -7500403 true true 177 40 38
Circle -7500403 true true 177 132 38
Circle -7500403 true true 70 85 38
Circle -7500403 true true 130 25 38
Circle -7500403 true true 96 51 108
Circle -16777216 true false 113 68 74
Polygon -10899396 true false 189 233 219 188 249 173 279 188 234 218
Polygon -10899396 true false 180 255 150 210 105 210 75 240 135 240

house
false
0
Rectangle -7500403 true true 45 120 255 285
Rectangle -16777216 true false 120 210 180 285
Polygon -7500403 true true 15 120 150 15 285 120
Line -16777216 false 30 120 270 120

leaf
false
0
Polygon -7500403 true true 150 210 135 195 120 210 60 210 30 195 60 180 60 165 15 135 30 120 15 105 40 104 45 90 60 90 90 105 105 120 120 120 105 60 120 60 135 30 150 15 165 30 180 60 195 60 180 120 195 120 210 105 240 90 255 90 263 104 285 105 270 120 285 135 240 165 240 180 270 195 240 210 180 210 165 195
Polygon -7500403 true true 135 195 135 240 120 255 105 255 105 285 135 285 165 240 165 195

line
true
0
Line -7500403 true 150 0 150 300

line half
true
0
Line -7500403 true 150 0 150 150

pentagon
false
0
Polygon -7500403 true true 150 15 15 120 60 285 240 285 285 120

person
false
0
Circle -7500403 true true 110 5 80
Polygon -7500403 true true 105 90 120 195 90 285 105 300 135 300 150 225 165 300 195 300 210 285 180 195 195 90
Rectangle -7500403 true true 127 79 172 94
Polygon -7500403 true true 195 90 240 150 225 180 165 105
Polygon -7500403 true true 105 90 60 150 75 180 135 105

plant
false
0
Rectangle -7500403 true true 135 90 165 300
Polygon -7500403 true true 135 255 90 210 45 195 75 255 135 285
Polygon -7500403 true true 165 255 210 210 255 195 225 255 165 285
Polygon -7500403 true true 135 180 90 135 45 120 75 180 135 210
Polygon -7500403 true true 165 180 165 210 225 180 255 120 210 135
Polygon -7500403 true true 135 105 90 60 45 45 75 105 135 135
Polygon -7500403 true true 165 105 165 135 225 105 255 45 210 60
Polygon -7500403 true true 135 90 120 45 150 15 180 45 165 90

sheep
false
15
Circle -1 true true 203 65 88
Circle -1 true true 70 65 162
Circle -1 true true 150 105 120
Polygon -7500403 true false 218 120 240 165 255 165 278 120
Circle -7500403 true false 214 72 67
Rectangle -1 true true 164 223 179 298
Polygon -1 true true 45 285 30 285 30 240 15 195 45 210
Circle -1 true true 3 83 150
Rectangle -1 true true 65 221 80 296
Polygon -1 true true 195 285 210 285 210 240 240 210 195 210
Polygon -7500403 true false 276 85 285 105 302 99 294 83
Polygon -7500403 true false 219 85 210 105 193 99 201 83

square
false
0
Rectangle -7500403 true true 30 30 270 270

square 2
false
0
Rectangle -7500403 true true 30 30 270 270
Rectangle -16777216 true false 60 60 240 240

star
false
0
Polygon -7500403 true true 151 1 185 108 298 108 207 175 242 282 151 216 59 282 94 175 3 108 116 108

target
false
0
Circle -7500403 true true 0 0 300
Circle -16777216 true false 30 30 240
Circle -7500403 true true 60 60 180
Circle -16777216 true false 90 90 120
Circle -7500403 true true 120 120 60

tree
false
0
Circle -7500403 true true 118 3 94
Rectangle -6459832 true false 120 195 180 300
Circle -7500403 true true 65 21 108
Circle -7500403 true true 116 41 127
Circle -7500403 true true 45 90 120
Circle -7500403 true true 104 74 152

triangle
false
0
Polygon -7500403 true true 150 30 15 255 285 255

triangle 2
false
0
Polygon -7500403 true true 150 30 15 255 285 255
Polygon -16777216 true false 151 99 225 223 75 224

truck
false
0
Rectangle -7500403 true true 4 45 195 187
Polygon -7500403 true true 296 193 296 150 259 134 244 104 208 104 207 194
Rectangle -1 true false 195 60 195 105
Polygon -16777216 true false 238 112 252 141 219 141 218 112
Circle -16777216 true false 234 174 42
Rectangle -7500403 true true 181 185 214 194
Circle -16777216 true false 144 174 42
Circle -16777216 true false 24 174 42
Circle -7500403 false true 24 174 42
Circle -7500403 false true 144 174 42
Circle -7500403 false true 234 174 42

turtle
true
0
Polygon -10899396 true false 215 204 240 233 246 254 228 266 215 252 193 210
Polygon -10899396 true false 195 90 225 75 245 75 260 89 269 108 261 124 240 105 225 105 210 105
Polygon -10899396 true false 105 90 75 75 55 75 40 89 31 108 39 124 60 105 75 105 90 105
Polygon -10899396 true false 132 85 134 64 107 51 108 17 150 2 192 18 192 52 169 65 172 87
Polygon -10899396 true false 85 204 60 233 54 254 72 266 85 252 107 210
Polygon -7500403 true true 119 75 179 75 209 101 224 135 220 225 175 261 128 261 81 224 74 135 88 99

wheel
false
0
Circle -7500403 true true 3 3 294
Circle -16777216 true false 30 30 240
Line -7500403 true 150 285 150 15
Line -7500403 true 15 150 285 150
Circle -7500403 true true 120 120 60
Line -7500403 true 216 40 79 269
Line -7500403 true 40 84 269 221
Line -7500403 true 40 216 269 79
Line -7500403 true 84 40 221 269

wolf
false
0
Polygon -16777216 true false 253 133 245 131 245 133
Polygon -7500403 true true 2 194 13 197 30 191 38 193 38 205 20 226 20 257 27 265 38 266 40 260 31 253 31 230 60 206 68 198 75 209 66 228 65 243 82 261 84 268 100 267 103 261 77 239 79 231 100 207 98 196 119 201 143 202 160 195 166 210 172 213 173 238 167 251 160 248 154 265 169 264 178 247 186 240 198 260 200 271 217 271 219 262 207 258 195 230 192 198 210 184 227 164 242 144 259 145 284 151 277 141 293 140 299 134 297 127 273 119 270 105
Polygon -7500403 true true -1 195 14 180 36 166 40 153 53 140 82 131 134 133 159 126 188 115 227 108 236 102 238 98 268 86 269 92 281 87 269 103 269 113

x
false
0
Polygon -7500403 true true 270 75 225 30 30 225 75 270
Polygon -7500403 true true 30 75 75 30 270 225 225 270
@#$#@#$#@
NetLogo 6.4.0
@#$#@#$#@
@#$#@#$#@
@#$#@#$#@
@#$#@#$#@
@#$#@#$#@
default
0.0
-0.2 0 0.0 1.0
0.0 1 1.0 0.0
0.2 0 0.0 1.0
link direction
true
0
Line -7500403 true 150 150 90 180
Line -7500403 true 150 150 210 180
@#$#@#$#@
0
@#$#@#$#@
