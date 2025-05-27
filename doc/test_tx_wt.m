clear;
close all;
pause(3);

bbtx = basebandTransceiver("My USRP N310");
interpolator = 4;
masterclockrate = 122.88e6;
samplerate = masterclockrate/interpolator
bbtx.SampleRate = samplerate;
bbtx.CenterFrequency = 2.33e9;
bbtx.RadioGain = 50;
bbtx
txWaveform = load("txwave_test.mat");
txWaveform_1 = txWaveform.txWaveform;
txWaveform_2 = txWaveform_1*0.5;
transmit(bbtx,txWaveform_1,"continuous");
disp('-----start transmitting!-----')
stopTransmission(bbtx);
transmit(bbtx,txWaveform_2,"continuous");
pause(5)
stopTransmission(bbtx);
disp('-----end transmitting!-----')
