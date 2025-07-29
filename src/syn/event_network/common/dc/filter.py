import matplotlib.pyplot as plt
import numpy as np
from control.matlab import *
from control import *

T_sample  = (1/125e6) * 2**10
T_analog  = 1 # s
T_digital = 2**16 # T_sample cycles

analog = tf([1], [T_analog, 1])
digitalized = sample_system(analog, Ts = T_sample, method = "impulse")
digital= tf([1/T_digital, 0], [1, (1-T_digital)/T_digital], dt = T_sample)

print(analog)
print(digitalized)
print(digital)

analog_response = frequency_response(analog) #, T=0.2)
#analog_response.sysname = "H(z) analog "
analog_response.plot()

digitalized_response = frequency_response(digitalized) #, T=0.2)
#digitalized_response.sysname = "H(z) digitalized "
digitalized_response.plot()

digital_response = frequency_response(digital,) # T=0.2)
#digital_response.sysname = "H(z) doc filter"
digital_response.plot()

#plt.plot(fs1, analog_response, label='Analog exp')
#plt.plot(fs2, digitalized_response, label='Digitalized')
#plt.plot(fs3, digital_response, label='Comfort coeff')
#plt.xscale('log')
plt.legend()
plt.grid(which='both')

plt.show()