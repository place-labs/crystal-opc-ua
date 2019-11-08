
## Negotiating a Secure Channel

1. Say Hello
2. Receive Acknowledgement
3. Request an insecure, secure channel (No Security)
4. Receive open channel response
5. Request available endpoints
6. This returns a list of supported security mechanisms
   * The highest supporteed security level returned should be utilised
7. Close the secure channel
8. Say Hello .. and re-negotiate an actually secure channel
