

# Installing D-Logic uFR Series RFID Reader Web extensions on ChromeOS


Hi there, if you are having trouble getting D-Logic's web extensions, [Found Here](https://code.d-logic.com/nfc-rfid-reader-sdk/ufr-browser_extensions) on chromeOS, then I have good news! A few configuration tweaks and a script and you are good to go.

Current Extension ID: kjfmmgpfhdohhcodbkaodgkidbenkgog


# Normal Installation

There are actually two steps to the installation of the web extension, even from the store.

1. Installation of the extension from firefox's debug or chrome's extensions screen.
2. Installation of the extension's HOST from the repository linked above. This differs based on your OS. There is an installer for Generic Windows, MacOS, Linux.


# Challenges on ChromeOS

This poses a problem on ChromeOS, because there is no way to run the downloaded script out of the box on chromeOS. So we have to use chrome OS's linux development environment, Crostini, to make the necessary extension host available. 

## Deeper

This makes things even more complicated, because even if we are able to run that script, chrome is still running on the host machine and not in the container. So then we have to install chromium inside the container...

If you have gotten this far, then you proably already know that script won't work anyway inside the container.
It doesn't place the extensions pieces into the right places. So I have a script and instructions on how to do that yourself here.

# From Fresh Install

## 1. Linux Development Environment   

Go to Settings -> About ChromeOS -> Scroll down to the bottom and toggle Linux Development Environment on.
It display a modal as it downloads the container image. After it's done, a terminal should open displaying your chosen username at the commandline. Type 'lsusb' to ensure that you are in the correct shell. Your RFID reader will not appear here yet.

## 2. Share USB with Linux

In ChromeOS, go back to Settings -> About ChromeOS -> Scroll down to the same place the toggle was at. It is now a submenu.
Click this submenu Linux Development Environment -> Manage USB devices -> The RFID reader that you should have plugged in at this step should show up in this list. If it is not showing up, plug it in and then click the notification that pops up at the bottom right to get back here.

In Linux Development Environment -> Manage USB devices -> Toggle the device showing your RFID reader's model name on.
Go back to your terminal

## 3. Install Chromium

In your terminal, update your package manager and then install chromium.

```
sudo apt update
sudo apt install chromium
```

When it is done installing, you will see a 'Linux apps' option in your start menu and a new app 'Chromium' on your system. They refer to the same app, but just in case, open the chromium browser that is inside of 'Linux Apps'.

## 4. Install extension from store

In a step that will later feel redundant, install the extension from the chrome store on the chromium browser.
https://chromewebstore.google.com/detail/nfc-reader-browser-extens/kjfmmgpfhdohhcodbkaodgkidbenkgog?pli=1

It will not work yet. If you enable developer mode at chrome://extensions and then inspect the service worker you will see it throwing errors if you attempt to use it. Note the extension ID of the reader extension. It's also in the URL above.

You should still have your terminal open. If you do not, then open another one using Ctrl+Shift+N or Search+Shift+N.

Close the chromium browser completely. 

## 5. Deploy extension resources from repository

In your terminal window, clone this repository or the web extensions repository. You don't need all of the folders, but it's easier this way.
```
git clone https://code.d-logic.com/nfc-rfid-reader-sdk/ufr-browser_extensions
```

We are interested in these files:

ufr-browser_extensions/Chrome/Host/Linux/ufr.dlogic.chrome.json
ufr-browser_extensions/Chrome/Host/Linux/com.dlogic.native.json
ufr-browser_extensions/Chrome/Host/Linux/x86_64/ufr
ufr-browser_extensions/Chrome/Host/Linux/x86/ufr**

** Only if you are not in a 64 bit system

We want both of those .json files to go into our native messaging host directory for chromium on crostini:

```
# ~/.config/chromium/NativeMessagingHosts/

cp ufr-browser_extensions/Chrome/Host/Linux/com.dlogic.native.json ~/.config/google-chrome/NativeMessagingHosts/
cp ufr-browser_extensions/Chrome/Host/Linux/com.dlogic.native.json ~/.config/google-chrome/NativeMessagingHosts/
```

Open these files one at a time and look for 'allowed origins'. Change the value to "chrome-extension://{Current Extension ID}".
In ufr.dlogic.chrome, note the "path" variable. For me, it was "/usr/local/bin/ufr". That's where the other piece goes.

Before continuing ensure permissions on the above files are set to 755.
```
# The only files here should be our new manifests
chmod 755 ~/.config/google-chrome/NativeMessagingHosts/* 
```

Finally, copy the extension host executable to the file mentioned in the manifest previously and ensure it has appropriate permissions.
```
cp ufr-browser_extensions/Chrome/Host/Linux/x86_64/ufr /usr/local/bin/
chmod +x+r /usr/local/bin/ufr
```