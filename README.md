Haxe Client Starter

This is a starter template for a simple Haxe application using Lime as its foundational base. 

It's called a "Client" because it is going to run either in a browser, or as a standalone application, and include a user interface. 

I suggest downloading the zip version of the Haxe CLient Starter, and unzipping it into a new directory to start a new Haxe project. 

https://github.com/Falagard/HaxeClientStarter

Click on the button that says Code, then choose Download Zip. 

Download to your computer, and extract the zip. 

Create a new directory on your computer where you want to keep your source files. Let's pretend it is C:\Src\MyClientProject 

Copy the contents of the zip to C:\Src\MyClientProject 

Install the Haxe toolkit from here: 

https://haxe.org/download/

Then install Haxe Module Manager (hmm) by opening a command prompt, run from anywhere:

haxelib --global install hmm
haxelib --global run hmm setup

Change directory into where this source is located, and install all dependencies:

hmm install

Install Visual Studio Code 

https://code.visualstudio.com/


Install the Lime extension

https://marketplace.visualstudio.com/items?itemName=openfl.lime-vscode-extension

Install the Hashlink debugger extension

https://marketplace.visualstudio.com/items?itemName=HaxeFoundation.haxe-hl

Open C:\Src\MyProject in Visual Studio Code 

In the bottom left of the window you should see the Lime extension's settings. Change the target from HTML5 to Hashlink/Debug 

Open MainView.hx and add a breakpoint in the button onclick function. 

Hit F5 

Congrats, you've successfully built, run and debugged a Haxe client application. 







