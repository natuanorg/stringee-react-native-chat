import { Component } from "react";
import PropTypes from "prop-types";
import { NativeModules, NativeEventEmitter, Platform } from "react-native";
import { clientEvents } from "./helpers/StringeeHelper";
import Conversation from "./chat/Conversation";
import Message from "./chat/Message";
import User from "./chat/User";
import { each } from "underscore";

const RNStringeeClient = NativeModules.RNStringeeClient;

const iOS = Platform.OS === "ios" ? true : false;

export default class extends Component {
  static propTypes = {
    eventHandlers: PropTypes.object
  };

  constructor(props) {
    super(props);
    this._events = [];
    this._subscriptions = [];
    this._eventEmitter = new NativeEventEmitter(RNStringeeClient);

    // Sinh uuid va tao wrapper object trong native
    this.uuid = Math.random().toString(36).substring(2, 15) + Math.random().toString(36).substring(2, 15) + Math.random().toString(36).substring(2, 15) + Math.random().toString(36).substring(2, 15);
    RNStringeeClient.createClientWrapper(this.uuid);
  }

  componentWillMount() {
    if (!iOS) {
      RNStringeeClient.init();
    }
    this.sanitizeClientEvents(this.props.eventHandlers);
  }

  componentWillUnmount() {
	  // Keep events for android
    if (!iOS) {
      return;
    }
    this._unregisterEvents();
  }

  render() {
    return null;
  }

  _unregisterEvents() {
    this._subscriptions.forEach(e => e.remove());
    this._subscriptions = [];

    this._events.forEach(e => RNStringeeClient.removeNativeEvent(this.uuid, e));
    this._events = [];
  }

  sanitizeClientEvents(events) {
    if (typeof events !== "object") {
      return;
    }
    const platform = Platform.OS;

    if (iOS) {
      each(events, (handler, type) => {
        const eventName = clientEvents[platform][type];
        if (eventName !== undefined) {
          // Voi phan chat can format du lieu
          if (type == "onObjectChange") {
            this._subscriptions.push(
              this._eventEmitter.addListener(eventName, ({ uuid, data }) => {
                // Event cua thang khac
                if (this.uuid != uuid) {
                  return;
                }

                var objectType = data["objectType"];
                var objects = data["objects"];
                var changeType = data["changeType"];

                var objectChanges = [];
                if (objectType == 0) {
                  objects.map((object) => {
                    objectChanges.push(new Conversation(object));
                  });
                } else if (objectType == 1) {
                  objects.map((object) => {
                    objectChanges.push(new Message(object));
                  });
                }
                
                handler({ objectType, objectChanges, changeType });
              })
            );
          } else {
            this._subscriptions.push(this._eventEmitter.addListener(eventName, ({uuid, data}) => {
              if (this.uuid == uuid) {
                handler(data);
              }
            }));
          }
  
          this._events.push(eventName);
          RNStringeeClient.setNativeEvent(this.uuid, eventName);
        } else {
          console.log(`${type} is not a supported event`);
        }
      });
    } else {
      each(events, (handler, type) => {
        const eventName = clientEvents[platform][type];
        if (eventName !== undefined) {
          if (!this._events.includes(eventName)) {
            // Voi phan chat can format du lieu
            if (type == "onObjectChange") {
              this._subscriptions.push(
                this._eventEmitter.addListener(eventName, ({ objectType, objects, changeType }) => {
                  var objectChanges = [];
                  if (objectType == 0) {
                    objects.map((object) => {
                      objectChanges.push(new Conversation(object));
                    });
                  } else if (objectType == 1) {
                    objects.map((object) => {
                      objectChanges.push(new Message(object));
                    });
                  }
                  handler({ objectType, objectChanges, changeType });
                })
              );
            } else {
              this._subscriptions.push(this._eventEmitter.addListener(eventName, data => {
                handler(data);
              }));
            }
    
            this._events.push(eventName);
            RNStringeeClient.setNativeEvent(this.uuid, eventName);
          }
        } else {
          console.log(`${type} is not a supported event`);
        }
      });
    }
  }

  getId() {
    return this.uuid;
  }

  connect(token: string) {
    RNStringeeClient.connect(this.uuid, token);
  }

  disconnect() {
    RNStringeeClient.disconnect(this.uuid);
  }

  registerPush(
    deviceToken: string,
    isProduction: boolean,
    isVoip: boolean,
    callback: RNStringeeEventCallback
  ) {
    if (iOS) {
      RNStringeeClient.registerPushForDeviceToken(
        this.uuid,
        deviceToken,
        isProduction,
        isVoip,
        callback
      );
    } else {
      RNStringeeClient.registerPushToken(deviceToken, callback);
    }
  }

  unregisterPush(deviceToken: string, callback: RNStringeeEventCallback) {
    RNStringeeClient.unregisterPushToken(this.uuid, deviceToken, callback);
  }

  sendCustomMessage(
    toUserId: string,
    message: string,
    callback: RNStringeeEventCallback
  ) {
    RNStringeeClient.sendCustomMessage(this.uuid, toUserId, message, callback);
  }

  createConversation(userIds, options, callback) {
    RNStringeeClient.createConversation(this.uuid, userIds, options, (status, code, message, conversation) => {
      var returnConversation;
      if (status) {
        returnConversation = new Conversation(conversation);
      }
      return callback(status, code, message, returnConversation);
    });
  }

  getConversationById(conversationId, callback) {
    RNStringeeClient.getConversationById(this.uuid, conversationId, (status, code, message, conversation) => {
      var returnConversation;
      if (status) {
        returnConversation = new Conversation(conversation);
      }
      return callback(status, code, message, returnConversation);
    });
  }

  getLocalConversations(userId: string, count, isAscending, callback) {
    var param = iOS ? count : userId;

    if (iOS) {
      // iOS su dung ca 2 tham so
      RNStringeeClient.getLocalConversations(this.uuid, count, userId, (status, code, message, conversations) => {
        var returnConversations = [];
        if (status) {
          if (isAscending) {
            conversations.reverse().map((conversation) => {
              returnConversations.push(new Conversation(conversation));
            });
          } else {
            conversations.map((conversation) => {
              returnConversations.push(new Conversation(conversation));
            });
          }
        }
        return callback(status, code, message, returnConversations);
      });
    } else {
      // Android chi su dung userId
      RNStringeeClient.getLocalConversations(userId, (status, code, message, conversations) => {
        var returnConversations = [];
        if (status) {
          if (isAscending) {
            conversations.reverse().map((conversation) => {
              returnConversations.push(new Conversation(conversation));
            });
          } else {
            conversations.map((conversation) => {
              returnConversations.push(new Conversation(conversation));
            });
          }
        }
        return callback(status, code, message, returnConversations);
      });
    }
  }

  getLastConversations(count, isAscending, callback) {
    RNStringeeClient.getLastConversations(this.uuid, count, (status, code, message, conversations) => {
      var returnConversations = [];
      if (status) {
        if (isAscending) {
          // Tăng dần -> Cần đảo mảng
          conversations.reverse().map((conversation) => {
            returnConversations.push(new Conversation(conversation));
          });
        } else {
          conversations.map((conversation) => {
            returnConversations.push(new Conversation(conversation));
          });
        }
      }
      return callback(status, code, message, returnConversations);
    });
  }

  getConversationsAfter(datetime, count, isAscending, callback) {
    RNStringeeClient.getConversationsAfter(this.uuid, datetime, count, (status, code, message, conversations) => {
      var returnConversations = [];
      if (status) {
        if (isAscending) {
          conversations.reverse().map((conversation) => {
            returnConversations.push(new Conversation(conversation));
          });
        } else {
          conversations.map((conversation) => {
            returnConversations.push(new Conversation(conversation));
          });
        }
      }
      return callback(status, code, message, returnConversations);
    });
  }

  getConversationsBefore(datetime, count, isAscending, callback) {
    RNStringeeClient.getConversationsBefore(this.uuid, datetime, count, (status, code, message, conversations) => {
      var returnConversations = [];
      if (status) {
        if (isAscending) {
          conversations.reverse().map((conversation) => {
            returnConversations.push(new Conversation(conversation));
          });
        } else {
          conversations.map((conversation) => {
            returnConversations.push(new Conversation(conversation));
          });
        }
      }
      return callback(status, code, message, returnConversations);
    });
  }

  deleteConversation(conversationId, callback) {
    RNStringeeClient.deleteConversation(this.uuid, conversationId, callback);
  }

  addParticipants(conversationId, userIds, callback) {
    RNStringeeClient.addParticipants(this.uuid, conversationId, userIds, (status, code, message, users) => {
      var returnUsers = [];
      if (status) {
        users.map((user) => {
          returnUsers.push(new User(user));
        });
      }
      return callback(status, code, message, returnUsers);
    });
  }

  removeParticipants(conversationId, userIds, callback) {
    RNStringeeClient.removeParticipants(this.uuid, conversationId, userIds, (status, code, message, users) => {
      var returnUsers = [];
      if (status) {
        users.map((user) => {
          returnUsers.push(new User(user));
        });
      }
      return callback(status, code, message, returnUsers);
    });
  }

  updateConversation(conversationId, params, callback) {
    RNStringeeClient.updateConversation(this.uuid, conversationId, params, callback);
  }

  markConversationAsRead(conversationId, callback) {
    RNStringeeClient.markConversationAsRead(this.uuid, conversationId, callback);
  }

  getConversationWithUser(userId, callback) {
    RNStringeeClient.getConversationWithUser(this.uuid, userId, (status, code, message, conversation) => {
      var returnConversation;
      if (status) {
        returnConversation = new Conversation(conversation);
      }
      return callback(status, code, message, returnConversation);
    });
  }

  getUnreadConversationCount(callback) {
    RNStringeeClient.getUnreadConversationCount(this.uuid, callback);
  }

  sendMessage(message, callback) {
    RNStringeeClient.sendMessage(this.uuid, message, callback);
  }

  deleteMessage(conversationId, messageId, callback) {
    RNStringeeClient.deleteMessage(this.uuid, conversationId, messageId, callback);
  }

  getLocalMessages(conversationId, count, isAscending, callback) {
    RNStringeeClient.getLocalMessages(this.uuid, conversationId, count, (status, code, message, messages) => {
      var returnMessages = [];
      if (status) {
        if (isAscending) {
          messages.map((msg) => {
            returnMessages.push(new Message(msg));
          });
        } else {
          messages.reverse().map((msg) => {
            returnMessages.push(new Message(msg));
          });
        }
      }
      return callback(status, code, message, returnMessages);
    });
  }

  getLastMessages(conversationId, count, isAscending, loadDeletedMessage, loadDeletedMessageContent, callback) {
    RNStringeeClient.getLastMessages(this.uuid, conversationId, count, loadDeletedMessage, loadDeletedMessageContent, (status, code, message, messages) => {
      var returnMessages = [];
      if (status) {
        if (isAscending) {
          messages.map((msg) => {
            returnMessages.push(new Message(msg));
          });
        } else {
          messages.reverse().map((msg) => {
            returnMessages.push(new Message(msg));
          });
        }
      }
      return callback(status, code, message, returnMessages);
    });
  }

  getMessagesAfter(conversationId, sequence, count, isAscending, loadDeletedMessage, loadDeletedMessageContent, callback) {
    RNStringeeClient.getMessagesAfter(this.uuid, conversationId, sequence, count, loadDeletedMessage, loadDeletedMessageContent, (status, code, message, messages) => {
      var returnMessages = [];
      if (status) {
        if (isAscending) {
          messages.map((msg) => {
            returnMessages.push(new Message(msg));
          });
        } else {
          messages.reverse().map((msg) => {
            returnMessages.push(new Message(msg));
          });
        }
      }
      return callback(status, code, message, returnMessages);
    });
  }

  getMessagesBefore(conversationId, sequence, count, isAscending, loadDeletedMessage, loadDeletedMessageContent, callback) {
    RNStringeeClient.getMessagesBefore(this.uuid, conversationId, sequence, count, loadDeletedMessage, loadDeletedMessageContent, (status, code, message, messages) => {
      var returnMessages = [];
      if (status) {
        if (isAscending) {
          messages.map((msg) => {
            returnMessages.push(new Message(msg));
          });
        } else {
          messages.reverse().map((msg) => {
            returnMessages.push(new Message(msg));
          });
        }
      }
      return callback(status, code, message, returnMessages);
    });
  }

  clearDb(callback) {
    RNStringeeClient.clearDb(this.uuid, callback);
  }
}
