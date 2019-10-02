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
  }

  componentWillMount() {
    if (!iOS) {
      RNStringeeClient.init();
    }
    this.sanitizeClientEvents(this.props.eventHandlers);
  }

  componentWillUnmount() {
    this._unregisterEvents();
  }

  render() {
    return null;
  }

  _unregisterEvents() {
    this._subscriptions.forEach(e => e.remove());
    this._subscriptions = [];

    this._events.forEach(e => RNStringeeClient.removeNativeEvent(e));
    this._events = [];
  }

  sanitizeClientEvents(events) {
    if (typeof events !== "object") {
      return;
    }
    const platform = Platform.OS;

    each(events, (handler, type) => {
      const eventName = clientEvents[platform][type];
      if (eventName !== undefined) {
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
        RNStringeeClient.setNativeEvent(eventName);
      } else {
        console.log(`${type} is not a supported event`);
      }
    });
  }

  connect(token: string) {
    RNStringeeClient.connect(token);
  }

  disconnect() {
    RNStringeeClient.disconnect();
  }

  registerPush(
    deviceToken: string,
    isProduction: boolean,
    isVoip: boolean,
    callback: RNStringeeEventCallback
  ) {
    if (iOS) {
      RNStringeeClient.registerPushForDeviceToken(
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
    RNStringeeClient.unregisterPushToken(deviceToken, callback);
  }

  sendCustomMessage(
    toUserId: string,
    message: string,
    callback: RNStringeeEventCallback
  ) {
    RNStringeeClient.sendCustomMessage(toUserId, message, callback);
  }

  createConversation(userIds, options, callback) {
    RNStringeeClient.createConversation(userIds, options, (status, code, message, conversation) => {
      var returnConversation;
      if (status) {
        returnConversation = new Conversation(conversation);
      }
      return callback(status, code, message, returnConversation);
    });
  }

  getConversationById(conversationId, callback) {
    RNStringeeClient.getConversationById(conversationId, (status, code, message, conversation) => {
      var returnConversation;
      if (status) {
        returnConversation = new Conversation(conversation);
      }
      return callback(status, code, message, returnConversation);
    });
  }

  getLocalConversations(userId: string, count, isAscending, callback) {
    var param = iOS ? count : userId;

    RNStringeeClient.getLocalConversations(param, (status, code, message, conversations) => {
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

  getLastConversations(count, isAscending, callback) {
    RNStringeeClient.getLastConversations(count, (status, code, message, conversations) => {
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
    RNStringeeClient.getConversationsAfter(datetime, count, (status, code, message, conversations) => {
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
    RNStringeeClient.getConversationsBefore(datetime, count, (status, code, message, conversations) => {
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
    RNStringeeClient.deleteConversation(conversationId, callback);
  }

  addParticipants(conversationId, userIds, callback) {
    RNStringeeClient.addParticipants(conversationId, userIds, (status, code, message, users) => {
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
    RNStringeeClient.removeParticipants(conversationId, userIds, (status, code, message, users) => {
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
    RNStringeeClient.updateConversation(conversationId, params, callback);
  }

  markConversationAsRead(conversationId, callback) {
    RNStringeeClient.markConversationAsRead(conversationId, callback);
  }

  getConversationWithUser(userId, callback) {
    RNStringeeClient.getConversationWithUser(userId, (status, code, message, conversation) => {
      var returnConversation;
      if (status) {
        returnConversation = new Conversation(conversation);
      }
      return callback(status, code, message, returnConversation);
    });
  }

  getUnreadConversationCount(callback) {
    RNStringeeClient.getUnreadConversationCount(callback);
  }

  sendMessage(message, callback) {
    RNStringeeClient.sendMessage(message, callback);
  }

  deleteMessage(conversationId, messageId, callback) {
    RNStringeeClient.deleteMessage(conversationId, messageId, callback);
  }

  getLocalMessages(conversationId, count, isAscending, callback) {
    RNStringeeClient.getLocalMessages(conversationId, count, (status, code, message, messages) => {
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

  getLastMessages(conversationId, count, isAscending, callback) {
    RNStringeeClient.getLastMessages(conversationId, count, (status, code, message, messages) => {
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

  getMessagesAfter(conversationId, sequence, count, isAscending, callback) {
    RNStringeeClient.getMessagesAfter(conversationId, sequence, count, (status, code, message, messages) => {
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

  getMessagesBefore(conversationId, sequence, count, isAscending, callback) {
    RNStringeeClient.getMessagesBefore(conversationId, sequence, count, (status, code, message, messages) => {
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
    RNStringeeClient.clearDb(callback);
  }
}
