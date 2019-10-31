### Setup and Run
1. Go to your [Realm dashboard](https://cloud.realm.io/instances) and create a new ROS instance
2. In `/realm-syncpermission-testTests/SyncPermissionTest.swift` enter the instance URL into `ROSHost`, removing the protocol (i.e. https://)
3. Choose an arbitrary string for the name and password of `userA` and `userB` (*You will need to change these each run*)
3. Execute `testEverything()`

#### Result
Your realm object server will be populated with random Thing objects and mutual permissions will be exchanged between `userA` and `userB`. You may follow along in the console output. The final step is for each user to read the others realm and present the list in the console output.
