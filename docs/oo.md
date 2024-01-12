# Object-Oriented Programming

Object-Oriented Programming (OOP) is a a programming paradigm employed by Task Engine. It aims to make programming with the framework easier, and to allow users to focus on one particular task. 

You're probably already familiar with _functions_ in programming, where you pass some data in, the function peforms an operation, and returns the altered data. This works well with simple procedures. The example below takes a number as an input argument, mulitplies it by two, and returns the output: 

```markdown
function output = multiplyByTwo(input)
    output = input * 2;
end

output = multiplyByTwo(4)

output =

     8
```

The important concept to grasp here is that all data that goes into the function (the number 4) and that comes out of the function (the number 8) is explicitly passed in and out. This becomes more of a problem when passing a lot of different variables into and out of a function. For example, when opening a Task Engine window for drawing, we need to specify the monitor number that the screen will open on, and the dimensions of the screen in cm. This requires two input arguments ('windowNumber' and 'monitorSize') and returns one output argument, the Psychtoolbox pointer of the screen:

```markdown
windowPtr = teOpenScreen(monitorNumber, monitorSize)

windowPtr = 

      10
```
 
So far, so good. However, there are situations where the screen dimenions are needed again. If we want to draw a stimulus with a position and size specified in cm, the 'teDrawStim' function needs to know the size of the monitor:

```markdown
teDrawStim(stim, monitorSize)
```

You can see that each and every time we draw a stimulus, we need to have a copy of the variable 'monitorSize' handy, and pass it to the function. If we want to convert from cm to pixels, we would call another function 'teScaleRect', and again would have to pass the monitor sizes. It would make more sense to tell Task Engine the size of the monitor once, and have it remember that value for any future operations. 

OOP addresses this by moving from the concept of _functions_ to _methods_ and _properties_. Methods are the equivalent of functions in that they do something to our data. Properties are the equivalent of variables (the data itself) and are stored within Task Engine. For example, if you want to open a screen and then draw, we call two methods, 'OpenWindow' and 'DrawStim'. Because we have already told Task Engine about the monitor size, it uses this value internally without us having to pass it to each method:

```
pres = tePresenter;
pres.MonitorSize = [34.5, 25.9];
pres.MonitorNumber = 0;
pres.OpenWindow;
pres.DrawStim(stim, rect);
```

This looks like more lines of code, but in fact we only have to set the monitor size and number once, and then any future operations - even if there are hundreds or thousands - will use those values without us having to pass them. 

### Objects

The _object_ in _object-oriented-programming_ is the entity that stores data and performs operations. In Task Engine the main object you will interact with is the 'tePresenter'. This manages all drawing and stimulus-related operations. You create an instance of an object by assigning it to a variable. This variable can be called whatever you like, but in this documentation I'll always name the instance of the 'tePresenter' class 'pres':

```
pres = tePresenter;
```

Once you have created an instance, you can access methods and properties using _dot notation_. To set a property, you reference it by name:

```
pres.MonitorSize = [30.5, 24.9];
```

Here we have told the presenter that the 'x' and 'y' dimensions of the monitor, in cm, are '34.5' and '24.9', respectively. Most monitors are sold with the screen dimensions referred to in terms of the diagonal size of the screen in inches (e.g. 17", 24"), and an aspect ratio (e.g. 4:3, 16:9). To make things easier, Task Engine has a _method_ to do this conversion:

```
pres.SetMonitorDiagonal(17, 4, 3, 'inches')
```

Here we have called the 'SetMonitorDiagonal' method, and passed the diagonal size (17"), and the x and y aspect ratio (4:3). We also specify that the units we are using are inches. Now, if we ask Task Engine for it's 'MonitorSize' values, we will get the correct size in cm:

```
pres.MonitorSize

ans =

                    34.544                    25.908
```

### Summary
That's it! All you need to know is that:

1. You create an _instance_ of an _object_: 'pres = tePresenter'
2. _Properties_ hold data: 'pres.MonitorSize = [30.5, 24.9]'
3. _Methods_ operate on data (like functions): 'pres.SetMonitorDiagonal(17, 4, 3, 'inches')'
