# ECG MQTT Service

The application described below includes a foreground service that receives an __ECG__ signal from the same application, transmitted via an __MQTT bridge__. The builtin __MQTT client-server__ receives the data and sends it to the application for playback. The application can also act as an __ECG signal generator__. In this case, the generated signal is sent to the network via the __MQTT__ __publish__ operation.

> _The application visualizes ECG signals from both its own generators and generators running on other phones._

Should be mentioned that the application was created gradually and below are listed the intermediate projects that became its basis.

* https://github.com/mk590901/ECG-Server
* https://github.com/mk590901/ECG-Pseudo-Service
* https://github.com/mk590901/ECG-FB-Service
* https://github.com/mk590901/flutter_fb_task

## Inside Application

The application consists of two parts:

* A __GUI__ part that includes a combination of a control panel, an __MQTT__ module status indicator, and a __+__ action button that allows to add __ECG signal generator__ as one of the cards (__widget__ for displaying the ECG signal) in the list of items. The __Start/Stop__ button on the control panel allows to start and stop the service. An item can be removed from the list either temporarily (swap from left to right) or permanently (using swap from right to left).

* The service is created using the __flutter_foreground_task plugin__. This plugin has built-in interfaces that ensure that the service receives data from the application and sends data to the application. The MQTT layer, implemented using __mqtt_client__, is part of the service and can work in the background.

In the context of the current application, the service provides:
* Connection to the MQTT bridge
* Subscription to a topic and receiving data via the network
* Sending data to the network via MQTT publish
* Automatic connection recovery when the subscription is terminated or disconnected.
* Responsible for the life cycle of __SimulatorWrapper__ objects that generate ECG signals.

Should be noted that items in the application list can be of two types: internal generators and external signal sources of the same application, but running on another device. This difference can be observed by a special ECG signal label containing the name of this device.

In this case, the movie shows the presence of __ECG__ signals from two phones: __Google Pixel 8__ and __LGE LM-810 (LG G8 ThinQ)__.

## Movie

The movie below shows the application's operation: can add an __ECG__ signal source, remove it from the list temporarily or permanently, and show __ECG__ signals running on other phones.

https://github.com/user-attachments/assets/bf1ee9d3-0cd7-453a-bc3f-90ae3a499e4f




