# Sessions

Broadly speaking, a session is started each time Task Engine runs (but see below for some nuances). Ideally, each participant will have one, and only one session per time point at which they are assessed. 

In reality, a script crashing, or being interrupted for any reason, will results in multiple sessions. This can cause problems at the analysis stage, so [split sessions](split sessions.md) of this type must be combined before analysis. Task Engine will by default offer to [resume](split sessions.md) a session if the same metadata (ID, time point, etc.) is entered twice. 

Sessions are assigned a [GUID](guid.md), which does not change, and are stamped with a date and time. Sessions are managed by the [teTracker](teTracker.md). 
