package com.stringeereactnative;

import android.content.Context;
import android.os.Bundle;
import android.support.annotation.Nullable;

import com.facebook.react.bridge.Arguments;
import com.facebook.react.bridge.Callback;
import com.facebook.react.bridge.ReactApplicationContext;
import com.facebook.react.bridge.ReactContext;
import com.facebook.react.bridge.ReactContextBaseJavaModule;
import com.facebook.react.bridge.ReactMethod;
import com.facebook.react.bridge.ReadableArray;
import com.facebook.react.bridge.ReadableMap;
import com.facebook.react.bridge.WritableArray;
import com.facebook.react.bridge.WritableMap;
import com.facebook.react.modules.core.DeviceEventManagerModule;
import com.stringee.StringeeClient;
import com.stringee.call.StringeeCall;
import com.stringee.exception.StringeeError;
import com.stringee.listener.StatusListener;
import com.stringee.listener.StringeeConnectionListener;
import com.stringee.messaging.Conversation;
import com.stringee.messaging.ConversationOptions;
import com.stringee.messaging.Message;
import com.stringee.messaging.StringeeChange;
import com.stringee.messaging.StringeeObject;
import com.stringee.messaging.User;
import com.stringee.messaging.listeners.CallbackListener;
import com.stringee.messaging.listeners.ChangeEventListenter;

import org.json.JSONArray;
import org.json.JSONException;
import org.json.JSONObject;

import java.util.ArrayList;
import java.util.Iterator;
import java.util.List;

public class RNStringeeClientModule extends ReactContextBaseJavaModule implements StringeeConnectionListener, ChangeEventListenter {

    private StringeeManager mStringeeManager;
    private StringeeClient mClient;
    private ArrayList<String> jsEvents = new ArrayList<String>();
    private Context mContext;

    public RNStringeeClientModule(ReactApplicationContext context) {
        super(context);
        mContext = context;
        mStringeeManager = StringeeManager.getInstance();
    }

    @Override
    public String getName() {
        return "RNStringeeClient";
    }

    @ReactMethod
    public void init() {
        mClient = mStringeeManager.getClient();
        if (mClient == null) {
            mClient = new StringeeClient(getReactApplicationContext());
            mClient.setConnectionListener(this);
            mClient.setChangeEventListenter(this);
        }

        mStringeeManager.setClient(mClient);
    }

    @ReactMethod
    public void connect(String accessToken) {
        if (mClient.isConnected()) {
            if (contains(jsEvents, "onConnectionConnected")) {
                WritableMap params = Arguments.createMap();
                params.putString("userId", mClient.getUserId());
                params.putInt("projectId", mClient.getProjectId());
                params.putBoolean("isReconnecting", false);
                sendEvent(getReactApplicationContext(), "onConnectionConnected", params);
            }
        } else {
            mClient.connect(accessToken);
        }
    }

    @ReactMethod
    public void disconnect() {
        if (mClient != null) {
            mClient.disconnect();
        }
    }

    @ReactMethod
    public void registerPushToken(String token, final Callback callback) {
        if (mClient == null) {
            callback.invoke(false, -1, "StringeeClient is not initialized or connected");
            return;
        }

        mClient.registerPushToken(token, new StatusListener() {
            @Override
            public void onSuccess() {
                callback.invoke(true, 0, "Success");
            }

            @Override
            public void onError(StringeeError error) {
                callback.invoke(false, error.getCode(), error.getMessage());
            }
        });
    }

    @ReactMethod
    public void unregisterPushToken(final String token, final Callback callback) {
        if (mClient == null) {
            callback.invoke(false, -1, "StringeeClient is not initialized or connected");
            return;
        }

        mClient.unregisterPushToken(token, new StatusListener() {
            @Override
            public void onSuccess() {
                callback.invoke(true, 0, "Success");
            }

            @Override
            public void onError(StringeeError error) {
                callback.invoke(false, error.getCode(), error.getMessage());
            }
        });
    }

    @ReactMethod
    public void sendCustomMessage(String toUser, String msg, final Callback callback) {
        if (mClient == null) {
            callback.invoke(false, -1, "StringeeClient is not initialized");
            return;
        }

        try {
            JSONObject jsonObject = new JSONObject(msg);
            mClient.sendCustomMessage(toUser, jsonObject, new StatusListener() {
                @Override
                public void onSuccess() {
                    callback.invoke(true, 0, "Success");
                }

                @Override
                public void onError(StringeeError error) {
                    callback.invoke(false, error.getCode(), error.getMessage());
                }
            });
        } catch (JSONException e) {
            e.printStackTrace();
            callback.invoke(false, -2, "Message is not not in JSON format");
        }
    }

    @Override
    public void onConnectionConnected(StringeeClient stringeeClient, boolean b) {
        if (contains(jsEvents, "onConnectionConnected")) {
            WritableMap params = Arguments.createMap();
            params.putString("userId", stringeeClient.getUserId());
            params.putInt("projectId", stringeeClient.getProjectId());
            params.putBoolean("isReconnecting", b);
            sendEvent(getReactApplicationContext(), "onConnectionConnected", params);
        }
    }

    @Override
    public void onConnectionDisconnected(StringeeClient stringeeClient, boolean b) {
        if (contains(jsEvents, "onConnectionDisconnected")) {
            WritableMap params = Arguments.createMap();
            params.putString("userId", stringeeClient.getUserId());
            params.putInt("projectId", stringeeClient.getProjectId());
            params.putBoolean("isReconnecting", b);
            sendEvent(getReactApplicationContext(), "onConnectionDisconnected", params);
        }
    }

    @Override
    public void onIncomingCall(StringeeCall stringeeCall) {
        if (contains(jsEvents, "onIncomingCall")) {
            StringeeManager.getInstance().getCallsMap().put(stringeeCall.getCallId(), stringeeCall);
            WritableMap params = Arguments.createMap();
            if (mClient != null) {
                params.putString("userId", mClient.getUserId());
            }
            params.putString("callId", stringeeCall.getCallId());
            params.putString("from", stringeeCall.getFrom());
            params.putString("to", stringeeCall.getTo());
            params.putString("fromAlias", stringeeCall.getFromAlias());
            params.putString("toAlias", stringeeCall.getToAlias());
            int callType = 1;
            if (stringeeCall.isPhoneToAppCall()) {
                callType = 3;
            }
            params.putInt("callType", callType);
            params.putBoolean("isVideoCall", stringeeCall.isVideoCall());
            params.putString("customDataFromYourServer", stringeeCall.getCustomDataFromYourServer());
            sendEvent(getReactApplicationContext(), "onIncomingCall", params);
        }
    }

    @Override
    public void onConnectionError(StringeeClient stringeeClient, StringeeError stringeeError) {
        if (contains(jsEvents, "onConnectionError")) {
            WritableMap params = Arguments.createMap();
            params.putInt("code", stringeeError.getCode());
            params.putString("message", stringeeError.getMessage());
            sendEvent(getReactApplicationContext(), "onConnectionError", params);
        }
    }

    @Override
    public void onRequestNewToken(StringeeClient stringeeClient) {
        if (contains(jsEvents, "onRequestNewToken")) {
            sendEvent(getReactApplicationContext(), "onRequestNewToken", null);
        }
    }

    @Override
    public void onCustomMessage(String s, JSONObject jsonObject) {
        if (contains(jsEvents, "onCustomMessage")) {
            WritableMap params = Arguments.createMap();
            params.putString("from", s);
            params.putString("data", jsonObject.toString());
            sendEvent(getReactApplicationContext(), "onCustomMessage", params);
        }
    }

    @Override
    public void onTopicMessage(String s, JSONObject jsonObject) {

    }

    private void sendEvent(ReactContext reactContext, String eventName, @Nullable WritableMap eventData) {
        reactContext
                .getJSModule(DeviceEventManagerModule.RCTDeviceEventEmitter.class)
                .emit(eventName, eventData);
    }

    @ReactMethod
    public void setNativeEvent(String event) {
        jsEvents.add(event);
    }

    @ReactMethod
    public void removeNativeEvent(String event) {
        jsEvents.remove(event);
    }

    private boolean contains(ArrayList array, String value) {

        for (int i = 0; i < array.size(); i++) {
            if (array.get(i).equals(value)) {
                return true;
            }
        }
        return false;
    }

    @ReactMethod
    public void createConversation(ReadableArray usersArray, ReadableMap optionsMap, final Callback callback) {
        if (mClient == null) {
            callback.invoke(false, -1, "StringeeClient is not initialized");
            return;
        }

        List<User> participants = new ArrayList<>();
        for (int i = 0; i < usersArray.size(); i++) {
            User user = new User(usersArray.getString(i));
            participants.add(user);
        }

        ConversationOptions convOptions = null;
        if (optionsMap != null) {
            convOptions = new ConversationOptions();
            if (optionsMap.hasKey("name")) {
                convOptions.setName(optionsMap.getString("name"));
            }
            if (optionsMap.hasKey("isGroup")) {
                convOptions.setGroup(optionsMap.getBoolean("isGroup"));
            }
            if (optionsMap.hasKey("isDistinct")) {
                convOptions.setDistinct(optionsMap.getBoolean("isDistinct"));
            }
        }

        mClient.createConversation(participants, convOptions, new CallbackListener<Conversation>() {
            @Override
            public void onSuccess(Conversation conversation) {
                WritableMap params = Arguments.createMap();
                params.putString("id", conversation.getId());
                params.putString("localId", conversation.getLocalId());
                params.putString("name", conversation.getName());
                params.putBoolean("isDistinct", conversation.isDistinct());
                params.putBoolean("isGroup", conversation.isGroup());
                params.putDouble("updatedAt", conversation.getUpdateAt());
                params.putString("lastMsgSender", conversation.getLastMsgSender());
                params.putInt("lastMsgType", conversation.getLastMsgType());
                params.putInt("unreadCount", conversation.getTotalUnread());
                params.putString("lastMsgId", conversation.getLastMsgId());
                params.putString("creator", conversation.getCreator());
                params.putDouble("created", conversation.getCreateAt());
                params.putDouble("lastMsgSeq", conversation.getLastMsgSeqReceived());
                params.putDouble("lastMsgCreatedAt", conversation.getLastTimeNewMsg());
                params.putInt("lastMsgState", conversation.getLastMsgState());
                if (conversation.getLastMsg() != null) {
                    try {
                        Bundle bundle = jsonToBundle(conversation.getLastMsg());
                        WritableMap lastMsgMap = Arguments.fromBundle(bundle);
                        params.putMap("text", lastMsgMap);
                    } catch (JSONException e) {
                        e.printStackTrace();
                    }
                }
                List<User> participants = conversation.getParticipants();
                WritableArray participantsMap = Arguments.createArray();
                for (int i = 0; i < participants.size(); i++) {
                    User user = participants.get(i);
                    WritableMap userMap = Arguments.createMap();
                    userMap.putString("userId", user.getUserId());
                    userMap.putString("name", user.getName());
                    userMap.putString("avatar", user.getAvatarUrl());
                    participantsMap.pushMap(userMap);
                }
                params.putArray("participants", participantsMap);
                callback.invoke(true, 0, "Success", params);
            }

            @Override
            public void onError(StringeeError error) {
                callback.invoke(false, error.getCode(), error.getMessage());
            }
        });
    }

    @ReactMethod
    public void getConversationById(String id, final Callback callback) {
        if (mClient == null) {
            callback.invoke(false, -1, "StringeeClient is not initialized");
            return;
        }

        if (id == null) {
            callback.invoke(false, -2, "Conversation id can not be null");
            return;
        }

        mClient.getConversation(id, new CallbackListener<Conversation>() {
            @Override
            public void onSuccess(Conversation conversation) {
                WritableMap params = Arguments.createMap();
                params.putString("id", conversation.getId());
                params.putString("localId", conversation.getLocalId());
                params.putString("name", conversation.getName());
                params.putBoolean("isDistinct", conversation.isDistinct());
                params.putBoolean("isGroup", conversation.isGroup());
                params.putDouble("updatedAt", conversation.getUpdateAt());
                params.putString("lastMsgSender", conversation.getLastMsgSender());
                params.putString("text", conversation.getText());
                params.putInt("lastMsgType", conversation.getLastMsgType());
                params.putInt("unreadCount", conversation.getTotalUnread());
                params.putString("lastMsgId", conversation.getLastMsgId());
                params.putString("creator", conversation.getCreator());
                params.putDouble("created", conversation.getCreateAt());
                params.putDouble("lastMsgSeq", conversation.getLastMsgSeqReceived());
                params.putDouble("lastMsgCreatedAt", conversation.getLastTimeNewMsg());
                params.putInt("lastMsgState", conversation.getLastMsgState());
                if (conversation.getLastMsg() != null) {
                    try {
                        Bundle bundle = jsonToBundle(conversation.getLastMsg());
                        WritableMap lastMsgMap = Arguments.fromBundle(bundle);
                        params.putMap("text", lastMsgMap);
                    } catch (JSONException e) {
                        e.printStackTrace();
                    }
                }
                List<User> participants = conversation.getParticipants();
                WritableArray participantsMap = Arguments.createArray();
                for (int i = 0; i < participants.size(); i++) {
                    User user = participants.get(i);
                    WritableMap userMap = Arguments.createMap();
                    userMap.putString("userId", user.getUserId());
                    userMap.putString("name", user.getName());
                    userMap.putString("avatar", user.getAvatarUrl());
                    participantsMap.pushMap(userMap);
                }
                params.putArray("participants", participantsMap);
                callback.invoke(true, 0, "Success", params);
            }

            @Override
            public void onError(StringeeError error) {
                callback.invoke(false, error.getCode(), error.getMessage());
            }
        });
    }

    @ReactMethod
    public void getLocalConversations(String userId, final Callback callback) {
        if (mClient == null) {
            callback.invoke(false, -1, "StringeeClient is not initialized");
            return;
        }

        if (userId == null) {
            callback.invoke(false, -2, "User id can not be null");
            return;
        }

        mClient.getLocalConversations(userId, new CallbackListener<List<Conversation>>() {
            @Override
            public void onSuccess(List<Conversation> conversations) {
                WritableArray params = Arguments.createArray();
                for (int i = 0; i < conversations.size(); i++) {
                    Conversation conversation = conversations.get(i);
                    WritableMap param = Arguments.createMap();
                    param.putString("id", conversation.getId());
                    param.putString("localId", conversation.getLocalId());
                    param.putString("name", conversation.getName());
                    param.putBoolean("isDistinct", conversation.isDistinct());
                    param.putBoolean("isGroup", conversation.isGroup());
                    param.putDouble("updatedAt", conversation.getUpdateAt());
                    param.putString("lastMsgSender", conversation.getLastMsgSender());
                    param.putString("text", conversation.getText());
                    param.putInt("lastMsgType", conversation.getLastMsgType());
                    param.putInt("unreadCount", conversation.getTotalUnread());
                    param.putString("lastMsgId", conversation.getLastMsgId());
                    param.putString("creator", conversation.getCreator());
                    param.putDouble("created", conversation.getCreateAt());
                    param.putDouble("lastMsgSeq", conversation.getLastMsgSeqReceived());
                    param.putDouble("lastMsgCreatedAt", conversation.getLastTimeNewMsg());
                    param.putInt("lastMsgState", conversation.getLastMsgState());
                    if (conversation.getLastMsg() != null) {
                        try {
                            Bundle bundle = jsonToBundle(conversation.getLastMsg());
                            WritableMap lastMsgMap = Arguments.fromBundle(bundle);
                            param.putMap("text", lastMsgMap);
                        } catch (JSONException e) {
                            e.printStackTrace();
                        }
                    }
                    List<User> participants = conversation.getParticipants();
                    WritableArray participantsMap = Arguments.createArray();
                    for (int j = 0; j < participants.size(); j++) {
                        User user = participants.get(j);
                        WritableMap userMap = Arguments.createMap();
                        userMap.putString("userId", user.getUserId());
                        userMap.putString("name", user.getName());
                        userMap.putString("avatar", user.getAvatarUrl());
                        participantsMap.pushMap(userMap);
                    }
                    param.putArray("participants", participantsMap);

                    params.pushMap(param);
                }
                callback.invoke(true, 0, "Success", params);
            }

            @Override
            public void onError(StringeeError error) {
                callback.invoke(false, error.getCode(), error.getMessage());
            }
        });
    }

    @ReactMethod
    public void getLastConversations(int count, final Callback callback) {
        if (mClient == null) {
            callback.invoke(false, -1, "StringeeClient is not initialized");
            return;
        }

        mClient.getLastConversations(count, new CallbackListener<List<Conversation>>() {
            @Override
            public void onSuccess(List<Conversation> conversations) {
                WritableArray params = Arguments.createArray();
                for (int i = 0; i < conversations.size(); i++) {
                    Conversation conversation = conversations.get(i);
                    WritableMap param = Arguments.createMap();
                    param.putString("id", conversation.getId());
                    param.putString("localId", conversation.getLocalId());
                    param.putString("name", conversation.getName());
                    param.putBoolean("isDistinct", conversation.isDistinct());
                    param.putBoolean("isGroup", conversation.isGroup());
                    param.putDouble("updatedAt", conversation.getUpdateAt());
                    param.putString("lastMsgSender", conversation.getLastMsgSender());
                    param.putString("text", conversation.getText());
                    param.putInt("lastMsgType", conversation.getLastMsgType());
                    param.putInt("unreadCount", conversation.getTotalUnread());
                    param.putString("lastMsgId", conversation.getLastMsgId());
                    param.putString("creator", conversation.getCreator());
                    param.putDouble("created", conversation.getCreateAt());
                    param.putDouble("lastMsgSeq", conversation.getLastMsgSeqReceived());
                    param.putDouble("lastMsgCreatedAt", conversation.getLastTimeNewMsg());
                    param.putInt("lastMsgState", conversation.getLastMsgState());
                    if (conversation.getLastMsg() != null) {
                        try {
                            Bundle bundle = jsonToBundle(conversation.getLastMsg());
                            WritableMap lastMsgMap = Arguments.fromBundle(bundle);
                            param.putMap("text", lastMsgMap);
                        } catch (JSONException e) {
                            e.printStackTrace();
                        }
                    }
                    List<User> participants = conversation.getParticipants();
                    WritableArray participantsMap = Arguments.createArray();
                    for (int j = 0; j < participants.size(); j++) {
                        User user = participants.get(j);
                        WritableMap userMap = Arguments.createMap();
                        userMap.putString("userId", user.getUserId());
                        userMap.putString("name", user.getName());
                        userMap.putString("avatar", user.getAvatarUrl());
                        participantsMap.pushMap(userMap);
                    }
                    param.putArray("participants", participantsMap);

                    params.pushMap(param);
                }
                callback.invoke(true, 0, "Success", params);
            }

            @Override
            public void onError(StringeeError error) {
                callback.invoke(false, error.getCode(), error.getMessage());
            }
        });
    }

    @ReactMethod
    public void getConversationsBefore(double datetime, int count, final Callback callback) {
        if (mClient == null) {
            callback.invoke(false, -1, "StringeeClient is not initialized or connected");
            return;
        }

        mClient.getConversationsBefore((long) datetime, count, new CallbackListener<List<Conversation>>() {
            @Override
            public void onSuccess(List<Conversation> conversations) {
                WritableArray params = Arguments.createArray();
                for (int i = 0; i < conversations.size(); i++) {
                    Conversation conversation = conversations.get(i);
                    WritableMap param = Arguments.createMap();
                    param.putString("id", conversation.getId());
                    param.putString("localId", conversation.getLocalId());
                    param.putString("name", conversation.getName());
                    param.putBoolean("isDistinct", conversation.isDistinct());
                    param.putBoolean("isGroup", conversation.isGroup());
                    param.putDouble("updatedAt", conversation.getUpdateAt());
                    param.putString("lastMsgSender", conversation.getLastMsgSender());
                    param.putString("text", conversation.getText());
                    param.putInt("lastMsgType", conversation.getLastMsgType());
                    param.putInt("unreadCount", conversation.getTotalUnread());
                    param.putString("lastMsgId", conversation.getLastMsgId());
                    param.putString("creator", conversation.getCreator());
                    param.putDouble("created", conversation.getCreateAt());
                    param.putDouble("lastMsgSeq", conversation.getLastMsgSeqReceived());
                    param.putDouble("lastMsgCreatedAt", conversation.getLastTimeNewMsg());
                    param.putInt("lastMsgState", conversation.getLastMsgState());
                    if (conversation.getLastMsg() != null) {
                        try {
                            Bundle bundle = jsonToBundle(conversation.getLastMsg());
                            WritableMap lastMsgMap = Arguments.fromBundle(bundle);
                            param.putMap("text", lastMsgMap);
                        } catch (JSONException e) {
                            e.printStackTrace();
                        }
                    }
                    List<User> participants = conversation.getParticipants();
                    WritableArray participantsMap = Arguments.createArray();
                    for (int j = 0; j < participants.size(); j++) {
                        User user = participants.get(j);
                        WritableMap userMap = Arguments.createMap();
                        userMap.putString("userId", user.getUserId());
                        userMap.putString("name", user.getName());
                        userMap.putString("avatar", user.getAvatarUrl());
                        participantsMap.pushMap(userMap);
                    }
                    param.putArray("participants", participantsMap);

                    params.pushMap(param);
                }
                callback.invoke(true, 0, "Success", params);
            }

            @Override
            public void onError(StringeeError error) {
                callback.invoke(false, error.getCode(), error.getMessage());
            }
        });
    }

    @ReactMethod
    public void getConversationsAfter(double datetime, int count, final Callback callback) {
        if (mClient == null) {
            callback.invoke(false, -1, "StringeeClient is not initialized or connected");
            return;
        }

        mClient.getConversationsAfter((long) datetime, count, new CallbackListener<List<Conversation>>() {
            @Override
            public void onSuccess(List<Conversation> conversations) {
                WritableArray params = Arguments.createArray();
                for (int i = 0; i < conversations.size(); i++) {
                    Conversation conversation = conversations.get(i);
                    WritableMap param = Arguments.createMap();
                    param.putString("id", conversation.getId());
                    param.putString("localId", conversation.getLocalId());
                    param.putString("name", conversation.getName());
                    param.putBoolean("isDistinct", conversation.isDistinct());
                    param.putBoolean("isGroup", conversation.isGroup());
                    param.putDouble("updatedAt", conversation.getUpdateAt());
                    param.putString("lastMsgSender", conversation.getLastMsgSender());
                    param.putString("text", conversation.getText());
                    param.putInt("lastMsgType", conversation.getLastMsgType());
                    param.putInt("unreadCount", conversation.getTotalUnread());
                    param.putString("lastMsgId", conversation.getLastMsgId());
                    param.putString("creator", conversation.getCreator());
                    param.putDouble("created", conversation.getCreateAt());
                    param.putDouble("lastMsgSeq", conversation.getLastMsgSeqReceived());
                    param.putDouble("lastMsgCreatedAt", conversation.getLastTimeNewMsg());
                    param.putInt("lastMsgState", conversation.getLastMsgState());
                    if (conversation.getLastMsg() != null) {
                        try {
                            Bundle bundle = jsonToBundle(conversation.getLastMsg());
                            WritableMap lastMsgMap = Arguments.fromBundle(bundle);
                            param.putMap("text", lastMsgMap);
                        } catch (JSONException e) {
                            e.printStackTrace();
                        }
                    }
                    List<User> participants = conversation.getParticipants();
                    WritableArray participantsMap = Arguments.createArray();
                    for (int j = 0; j < participants.size(); j++) {
                        User user = participants.get(j);
                        WritableMap userMap = Arguments.createMap();
                        userMap.putString("userId", user.getUserId());
                        userMap.putString("name", user.getName());
                        userMap.putString("avatar", user.getAvatarUrl());
                        participantsMap.pushMap(userMap);
                    }
                    param.putArray("participants", participantsMap);

                    params.pushMap(param);
                }
                callback.invoke(true, 0, "Success", params);
            }

            @Override
            public void onError(StringeeError error) {
                callback.invoke(false, error.getCode(), error.getMessage());
            }
        });
    }

    @ReactMethod
    public void deleteConversation(String convId, final Callback callback) {
        if (mClient == null) {
            callback.invoke(false, -1, "StringeeClient is not initialized or connected");
            return;
        }

        mClient.getConversation(convId, new CallbackListener<Conversation>() {
            @Override
            public void onSuccess(final Conversation conversation) {
                if (conversation.isGroup()) {
                    if (conversation.getState() != Conversation.STATE_LEFT) {
                        callback.invoke(false, -2, "You must leave this group before deleting");
                        return;
                    }
                }
                conversation.delete(mClient, new StatusListener() {
                    @Override
                    public void onSuccess() {
                        callback.invoke(true, 0, "Success");
                    }

                    @Override
                    public void onError(StringeeError error) {
                        callback.invoke(false, error.getCode(), error.getMessage());
                    }
                });
            }

            @Override
            public void onError(StringeeError error) {
                callback.invoke(false, error.getCode(), error.getMessage());
            }
        });
    }

    @ReactMethod
    public void addParticipants(String convId, final ReadableArray usersArray, final Callback callback) {
        if (mClient == null) {
            callback.invoke(false, -1, "StringeeClient is not initialized or connected");
            return;
        }

        mClient.getConversation(convId, new CallbackListener<Conversation>() {
            @Override
            public void onSuccess(Conversation conversation) {
                List<User> users = new ArrayList<>();
                for (int i = 0; i < usersArray.size(); i++) {
                    User user = new User(usersArray.getString(i));
                    users.add(user);
                }
                conversation.addParticipants(mClient, users, new CallbackListener<List<User>>() {
                    @Override
                    public void onSuccess(List<User> users) {
                        WritableArray params = Arguments.createArray();
                        for (int i = 0; i < users.size(); i++) {
                            User user = users.get(i);
                            WritableMap param = Arguments.createMap();
                            param.putString("userId", user.getUserId());
                            param.putString("name", user.getName());
                            param.putString("avatar", user.getAvatarUrl());
                            params.pushMap(param);
                        }

                        callback.invoke(true, 0, "Success", params);
                    }

                    @Override
                    public void onError(StringeeError error) {
                        callback.invoke(false, error.getCode(), error.getMessage());
                    }
                });
            }

            @Override
            public void onError(StringeeError error) {
                callback.invoke(false, error.getCode(), error.getMessage());
            }
        });
    }

    @ReactMethod
    public void removeParticipants(String convId, final ReadableArray usersArray, final Callback callback) {
        if (mClient == null) {
            callback.invoke(false, -1, "StringeeClient is not initialized or connected");
            return;
        }

        mClient.getConversation(convId, new CallbackListener<Conversation>() {
            @Override
            public void onSuccess(Conversation conversation) {
                List<User> users = new ArrayList<>();
                for (int i = 0; i < usersArray.size(); i++) {
                    User user = new User(usersArray.getString(i));
                    users.add(user);
                }
                conversation.removeParticipants(mClient, users, new CallbackListener<List<User>>() {
                    @Override
                    public void onSuccess(List<User> users) {
                        WritableArray params = Arguments.createArray();
                        for (int i = 0; i < users.size(); i++) {
                            User user = users.get(i);
                            WritableMap param = Arguments.createMap();
                            param.putString("userId", user.getUserId());
                            param.putString("name", user.getName());
                            param.putString("avatar", user.getAvatarUrl());
                            params.pushMap(param);
                        }

                        callback.invoke(true, 0, "Success", params);
                    }

                    @Override
                    public void onError(StringeeError error) {
                        callback.invoke(false, error.getCode(), error.getMessage());
                    }
                });
            }

            @Override
            public void onError(StringeeError error) {
                callback.invoke(false, error.getCode(), error.getMessage());
            }
        });
    }

    @ReactMethod
    public void sendMessage(ReadableMap messageMap, final Callback callback) {
        if (mClient == null) {
            callback.invoke(false, -1, "StringeeClient is not initialized or connected");
            return;
        }

        String convId = messageMap.getString("convId");
        final int type = messageMap.getInt("type");
        final ReadableMap msgMap = messageMap.getMap("message");

        mClient.getConversation(convId, new CallbackListener<Conversation>() {
            @Override
            public void onSuccess(Conversation conversation) {
                Message message = new Message(type);
                switch (type) {
                    case 1:
                        message = new Message(msgMap.getString("content"));
                        break;
                    case 2:
                        message.setFileUrl(msgMap.getString("filePath"));
                        message.setThumbnailUrl(msgMap.getString("thumbnail"));
                        message.setImageRatio((float) msgMap.getDouble("ratio"));
                        break;
                    case 3:
                        message.setFileUrl(msgMap.getString("filePath"));
                        message.setThumbnailUrl(msgMap.getString("thumbnail"));
                        message.setImageRatio((float) msgMap.getDouble("ratio"));
                        message.setDuration(msgMap.getInt("duration"));
                        break;
                    case 4:
                        message.setFileUrl(msgMap.getString("filePath"));
                        message.setDuration(msgMap.getInt("duration"));
                        break;
                    case 5:
                        message.setFileUrl(msgMap.getString("filePath"));
                        message.setFileName(msgMap.getString("filename"));
                        message.setFileLength(msgMap.getInt("length"));
                        break;
                    case 9:
                        message.setLatitude(msgMap.getDouble("lat"));
                        message.setLongitude(msgMap.getDouble("lon"));
                        break;
                    case 10:
                        message.setContact(msgMap.getString("vcard"));
                        break;
                    case 11:
                        message.setStickerCategory(msgMap.getString("category"));
                        message.setStickerName(msgMap.getString("name"));
                        break;
                    default:
                        break;
                }

                conversation.sendMessage(mClient, message, new StatusListener() {
                    @Override
                    public void onSuccess() {
                        callback.invoke(true, 0, "Success");
                    }

                    @Override
                    public void onError(StringeeError error) {
                        callback.invoke(false, error.getCode(), error.getMessage());
                    }
                });
            }

            @Override
            public void onError(StringeeError error) {
                callback.invoke(false, error.getCode(), error.getMessage());
            }
        });
    }

    @ReactMethod
    public void getLocalMessages(String convId, final int count, final Callback callback) {
        if (mClient == null) {
            callback.invoke(false, -1, "StringeeClient is not initialized or connected");
            return;
        }

        mClient.getConversation(convId, new CallbackListener<Conversation>() {
            @Override
            public void onSuccess(Conversation conversation) {
                conversation.getLocalMessages(mClient, count, new CallbackListener<List<Message>>() {
                    @Override
                    public void onSuccess(List<Message> messages) {
                        WritableArray params = Arguments.createArray();
                        for (int i = 0; i < messages.size(); i++) {
                            Message message = messages.get(i);
                            WritableMap param = Arguments.createMap();
                            param.putString("id", message.getId());
                            param.putString("localId", message.getLocalId());
                            param.putString("conversationId", message.getConversationId());
                            param.putDouble("createdAt", message.getCreatedAt());
                            param.putInt("state", message.getState().getValue());
                            param.putDouble("sequence", message.getSequence());
                            param.putInt("type", message.getType());
                            WritableMap contentMap = Arguments.createMap();
                            switch (message.getType()) {
                                case 1:
                                    contentMap.putString("content", message.getText());
                                    break;
                                case 2:
                                    WritableMap photoMap = Arguments.createMap();
                                    photoMap.putString("filePath", message.getFileUrl());
                                    photoMap.putString("thumbnail", message.getThumbnailUrl());
                                    photoMap.putDouble("ratio", message.getImageRatio());
                                    contentMap.putMap("photo", photoMap);
                                    break;
                                case 3:
                                    WritableMap videoMap = Arguments.createMap();
                                    videoMap.putString("filePath", message.getFileUrl());
                                    videoMap.putString("thumbnail", message.getThumbnailUrl());
                                    videoMap.putDouble("ratio", message.getImageRatio());
                                    videoMap.putInt("duration", message.getDuration());
                                    contentMap.putMap("video", videoMap);
                                    break;
                                case 4:
                                    WritableMap audioMap = Arguments.createMap();
                                    audioMap.putString("filePath", message.getFileUrl());
                                    audioMap.putInt("duration", message.getDuration());
                                    contentMap.putMap("audio", audioMap);
                                    break;
                                case 5:
                                    WritableMap fileMap = Arguments.createMap();
                                    fileMap.putString("filePath", message.getFileUrl());
                                    fileMap.putString("filename", message.getFileName());
                                    fileMap.putDouble("length", message.getFileLength());
                                    contentMap.putMap("file", fileMap);
                                    break;
                                case 7:
                                    try {
                                        contentMap = Arguments.fromBundle(jsonToBundle(message.getText()));
                                    } catch (JSONException e) {
                                        e.printStackTrace();
                                    }
                                    break;
                                case 9:
                                    WritableMap locationMap = Arguments.createMap();
                                    locationMap.putDouble("lat", message.getLatitude());
                                    locationMap.putDouble("lon", message.getLongitude());
                                    contentMap.putMap("location", locationMap);
                                    break;
                                case 10:
                                    WritableMap contactMap = Arguments.createMap();
                                    contactMap.putString("vcard", message.getContact());
                                    contentMap.putMap("contact", contactMap);
                                    break;
                                case 11:
                                    WritableMap stickerMap = Arguments.createMap();
                                    stickerMap.putString("name", message.getStickerName());
                                    stickerMap.putString("category", message.getStickerCategory());
                                    contentMap.putMap("sticker", stickerMap);
                                    break;
                                case 100:
                                    try {
                                        contentMap = Arguments.fromBundle(jsonToBundle(message.getText()));
                                    } catch (JSONException e) {
                                        e.printStackTrace();
                                    }
                                    break;
                            }
                            param.putMap("content", contentMap);
                            String senderId = message.getSenderId();
                            User user = mClient.getUser(senderId);
                            String name = "";
                            if (user != null) {
                                name = user.getName();
                                if (name == null || name.length() == 0) {
                                    name = user.getUserId();
                                }
                            }
                            param.putString("sender", name);
                            params.pushMap(param);
                        }
                        callback.invoke(true, 0, "Success", params);
                    }

                    @Override
                    public void onError(StringeeError error) {
                        callback.invoke(false, error.getCode(), error.getMessage());
                    }
                });
            }

            @Override
            public void onError(StringeeError error) {
                callback.invoke(false, error.getCode(), error.getMessage());
            }
        });
    }

    @ReactMethod
    public void getLastMessages(String convId, final int count, final Callback callback) {
        if (mClient == null) {
            callback.invoke(false, -1, "StringeeClient is not initialized or connected");
            return;
        }

        mClient.getConversation(convId, new CallbackListener<Conversation>() {
            @Override
            public void onSuccess(Conversation conversation) {
                conversation.getLastMessages(mClient, count, new CallbackListener<List<Message>>() {
                    @Override
                    public void onSuccess(List<Message> messages) {
                        WritableArray params = Arguments.createArray();
                        for (int i = 0; i < messages.size(); i++) {
                            Message message = messages.get(i);
                            WritableMap param = Arguments.createMap();
                            param.putString("id", message.getId());
                            param.putString("localId", message.getLocalId());
                            param.putString("conversationId", message.getConversationId());
                            param.putDouble("createdAt", message.getCreatedAt());
                            param.putInt("state", message.getState().getValue());
                            param.putDouble("sequence", message.getSequence());
                            param.putInt("type", message.getType());
                            WritableMap contentMap = Arguments.createMap();
                            switch (message.getType()) {
                                case 1:
                                    contentMap.putString("content", message.getText());
                                    break;
                                case 2:
                                    WritableMap photoMap = Arguments.createMap();
                                    photoMap.putString("filePath", message.getFileUrl());
                                    photoMap.putString("thumbnail", message.getThumbnailUrl());
                                    photoMap.putDouble("ratio", message.getImageRatio());
                                    contentMap.putMap("photo", photoMap);
                                    break;
                                case 3:
                                    WritableMap videoMap = Arguments.createMap();
                                    videoMap.putString("filePath", message.getFileUrl());
                                    videoMap.putString("thumbnail", message.getThumbnailUrl());
                                    videoMap.putDouble("ratio", message.getImageRatio());
                                    videoMap.putInt("duration", message.getDuration());
                                    contentMap.putMap("video", videoMap);
                                    break;
                                case 4:
                                    WritableMap audioMap = Arguments.createMap();
                                    audioMap.putString("filePath", message.getFileUrl());
                                    audioMap.putInt("duration", message.getDuration());
                                    contentMap.putMap("audio", audioMap);
                                    break;
                                case 5:
                                    WritableMap fileMap = Arguments.createMap();
                                    fileMap.putString("filePath", message.getFileUrl());
                                    fileMap.putString("filename", message.getFileName());
                                    fileMap.putDouble("length", message.getFileLength());
                                    contentMap.putMap("file", fileMap);
                                    break;
                                case 7:
                                    try {
                                        contentMap = Arguments.fromBundle(jsonToBundle(message.getText()));
                                    } catch (JSONException e) {
                                        e.printStackTrace();
                                    }
                                    break;
                                case 9:
                                    WritableMap locationMap = Arguments.createMap();
                                    locationMap.putDouble("lat", message.getLatitude());
                                    locationMap.putDouble("lon", message.getLongitude());
                                    contentMap.putMap("location", locationMap);
                                    break;
                                case 10:
                                    WritableMap contactMap = Arguments.createMap();
                                    contactMap.putString("vcard", message.getContact());
                                    contentMap.putMap("contact", contactMap);
                                    break;
                                case 11:
                                    WritableMap stickerMap = Arguments.createMap();
                                    stickerMap.putString("name", message.getStickerName());
                                    stickerMap.putString("category", message.getStickerCategory());
                                    contentMap.putMap("sticker", stickerMap);
                                    break;
                                case 100:
                                    try {
                                        contentMap = Arguments.fromBundle(jsonToBundle(message.getText()));
                                    } catch (JSONException e) {
                                        e.printStackTrace();
                                    }
                                    break;
                            }
                            param.putMap("content", contentMap);
                            String senderId = message.getSenderId();
                            User user = mClient.getUser(senderId);
                            String name = "";
                            if (user != null) {
                                name = user.getName();
                                if (name == null || name.length() == 0) {
                                    name = user.getUserId();
                                }
                            }
                            param.putString("sender", name);
                            params.pushMap(param);
                        }
                        callback.invoke(true, 0, "Success", params);
                    }

                    @Override
                    public void onError(StringeeError error) {
                        callback.invoke(false, error.getCode(), error.getMessage());
                    }
                });
            }

            @Override
            public void onError(StringeeError error) {
                callback.invoke(false, error.getCode(), error.getMessage());
            }
        });
    }


    @ReactMethod
    public void getMessagesAfter(String convId, final int sequence, final int count, final Callback callback) {
        if (mClient == null) {
            callback.invoke(false, -1, "StringeeClient is not initialized or connected");
            return;
        }

        mClient.getConversation(convId, new CallbackListener<Conversation>() {
            @Override
            public void onSuccess(Conversation conversation) {
                conversation.getMessagesAfter(mClient, sequence, count, new CallbackListener<List<Message>>() {
                    @Override
                    public void onSuccess(List<Message> messages) {
                        WritableArray params = Arguments.createArray();
                        for (int i = 0; i < messages.size(); i++) {
                            Message message = messages.get(i);
                            WritableMap param = Arguments.createMap();
                            param.putString("id", message.getId());
                            param.putString("localId", message.getLocalId());
                            param.putString("conversationId", message.getConversationId());
                            param.putDouble("createdAt", message.getCreatedAt());
                            param.putInt("state", message.getState().getValue());
                            param.putDouble("sequence", message.getSequence());
                            param.putInt("type", message.getType());
                            WritableMap contentMap = Arguments.createMap();
                            switch (message.getType()) {
                                case 1:
                                    contentMap.putString("content", message.getText());
                                    break;
                                case 2:
                                    WritableMap photoMap = Arguments.createMap();
                                    photoMap.putString("filePath", message.getFileUrl());
                                    photoMap.putString("thumbnail", message.getThumbnailUrl());
                                    photoMap.putDouble("ratio", message.getImageRatio());
                                    contentMap.putMap("photo", photoMap);
                                    break;
                                case 3:
                                    WritableMap videoMap = Arguments.createMap();
                                    videoMap.putString("filePath", message.getFileUrl());
                                    videoMap.putString("thumbnail", message.getThumbnailUrl());
                                    videoMap.putDouble("ratio", message.getImageRatio());
                                    videoMap.putInt("duration", message.getDuration());
                                    contentMap.putMap("video", videoMap);
                                    break;
                                case 4:
                                    WritableMap audioMap = Arguments.createMap();
                                    audioMap.putString("filePath", message.getFileUrl());
                                    audioMap.putInt("duration", message.getDuration());
                                    contentMap.putMap("audio", audioMap);
                                    break;
                                case 5:
                                    WritableMap fileMap = Arguments.createMap();
                                    fileMap.putString("filePath", message.getFileUrl());
                                    fileMap.putString("filename", message.getFileName());
                                    fileMap.putDouble("length", message.getFileLength());
                                    contentMap.putMap("file", fileMap);
                                    break;
                                case 7:
                                    try {
                                        contentMap = Arguments.fromBundle(jsonToBundle(message.getText()));
                                    } catch (JSONException e) {
                                        e.printStackTrace();
                                    }
                                    break;
                                case 9:
                                    WritableMap locationMap = Arguments.createMap();
                                    locationMap.putDouble("lat", message.getLatitude());
                                    locationMap.putDouble("lon", message.getLongitude());
                                    contentMap.putMap("location", locationMap);
                                    break;
                                case 10:
                                    WritableMap contactMap = Arguments.createMap();
                                    contactMap.putString("vcard", message.getContact());
                                    contentMap.putMap("contact", contactMap);
                                    break;
                                case 11:
                                    WritableMap stickerMap = Arguments.createMap();
                                    stickerMap.putString("name", message.getStickerName());
                                    stickerMap.putString("category", message.getStickerCategory());
                                    contentMap.putMap("sticker", stickerMap);
                                    break;
                                case 100:
                                    try {
                                        contentMap = Arguments.fromBundle(jsonToBundle(message.getText()));
                                    } catch (JSONException e) {
                                        e.printStackTrace();
                                    }
                                    break;
                            }
                            param.putMap("content", contentMap);
                            String senderId = message.getSenderId();
                            User user = mClient.getUser(senderId);
                            String name = "";
                            if (user != null) {
                                name = user.getName();
                                if (name == null || name.length() == 0) {
                                    name = user.getUserId();
                                }
                            }
                            param.putString("sender", name);
                            params.pushMap(param);
                        }
                        callback.invoke(true, 0, "Success", params);
                    }

                    @Override
                    public void onError(StringeeError error) {
                        callback.invoke(false, error.getCode(), error.getMessage());
                    }
                });
            }

            @Override
            public void onError(StringeeError error) {
                callback.invoke(false, error.getCode(), error.getMessage());
            }
        });
    }

    @ReactMethod
    public void getMessagesBefore(String convId, final int sequence, final int count, final Callback callback) {
        if (mClient == null) {
            callback.invoke(false, -1, "StringeeClient is not initialized or connected");
            return;
        }

        mClient.getConversation(convId, new CallbackListener<Conversation>() {
            @Override
            public void onSuccess(Conversation conversation) {
                conversation.getMessagesBefore(mClient, sequence, count, new CallbackListener<List<Message>>() {
                    @Override
                    public void onSuccess(List<Message> messages) {
                        WritableArray params = Arguments.createArray();
                        for (int i = 0; i < messages.size(); i++) {
                            Message message = messages.get(i);
                            WritableMap param = Arguments.createMap();
                            param.putString("id", message.getId());
                            param.putString("localId", message.getLocalId());
                            param.putString("conversationId", message.getConversationId());
                            param.putDouble("createdAt", message.getCreatedAt());
                            param.putInt("state", message.getState().getValue());
                            param.putDouble("sequence", message.getSequence());
                            param.putInt("type", message.getType());
                            WritableMap contentMap = Arguments.createMap();
                            switch (message.getType()) {
                                case 1:
                                    contentMap.putString("content", message.getText());
                                    break;
                                case 2:
                                    WritableMap photoMap = Arguments.createMap();
                                    photoMap.putString("filePath", message.getFileUrl());
                                    photoMap.putString("thumbnail", message.getThumbnailUrl());
                                    photoMap.putDouble("ratio", message.getImageRatio());
                                    contentMap.putMap("photo", photoMap);
                                    break;
                                case 3:
                                    WritableMap videoMap = Arguments.createMap();
                                    videoMap.putString("filePath", message.getFileUrl());
                                    videoMap.putString("thumbnail", message.getThumbnailUrl());
                                    videoMap.putDouble("ratio", message.getImageRatio());
                                    videoMap.putInt("duration", message.getDuration());
                                    contentMap.putMap("video", videoMap);
                                    break;
                                case 4:
                                    WritableMap audioMap = Arguments.createMap();
                                    audioMap.putString("filePath", message.getFileUrl());
                                    audioMap.putInt("duration", message.getDuration());
                                    contentMap.putMap("audio", audioMap);
                                    break;
                                case 5:
                                    WritableMap fileMap = Arguments.createMap();
                                    fileMap.putString("filePath", message.getFileUrl());
                                    fileMap.putString("filename", message.getFileName());
                                    fileMap.putDouble("length", message.getFileLength());
                                    contentMap.putMap("file", fileMap);
                                    break;
                                case 7:
                                    try {
                                        contentMap = Arguments.fromBundle(jsonToBundle(message.getText()));
                                    } catch (JSONException e) {
                                        e.printStackTrace();
                                    }
                                    break;

                                case 9:
                                    WritableMap locationMap = Arguments.createMap();
                                    locationMap.putDouble("lat", message.getLatitude());
                                    locationMap.putDouble("lon", message.getLongitude());
                                    contentMap.putMap("location", locationMap);
                                    break;
                                case 10:
                                    WritableMap contactMap = Arguments.createMap();
                                    contactMap.putString("vcard", message.getContact());
                                    contentMap.putMap("contact", contactMap);
                                    break;
                                case 11:
                                    WritableMap stickerMap = Arguments.createMap();
                                    stickerMap.putString("name", message.getStickerName());
                                    stickerMap.putString("category", message.getStickerCategory());
                                    contentMap.putMap("sticker", stickerMap);
                                    break;
                                case 100:
                                    try {
                                        contentMap = Arguments.fromBundle(jsonToBundle(message.getText()));
                                    } catch (JSONException e) {
                                        e.printStackTrace();
                                    }
                                    break;
                            }
                            param.putMap("content", contentMap);
                            String senderId = message.getSenderId();
                            User user = mClient.getUser(senderId);
                            String name = "";
                            if (user != null) {
                                name = user.getName();
                                if (name == null || name.length() == 0) {
                                    name = user.getUserId();
                                }
                            }
                            param.putString("sender", name);
                            params.pushMap(param);
                        }
                        callback.invoke(true, 0, "Success", params);
                    }

                    @Override
                    public void onError(StringeeError error) {
                        callback.invoke(false, error.getCode(), error.getMessage());
                    }
                });
            }

            @Override
            public void onError(StringeeError error) {
                callback.invoke(false, error.getCode(), error.getMessage());
            }
        });
    }

    @ReactMethod
    public void deleteMessage(String convId, final String msgId, final Callback callback) {
        if (mClient == null) {
            callback.invoke(false, -1, "StringeeClient is not initialized or connected");
            return;
        }

        JSONArray messageIds = new JSONArray();
        messageIds.put(msgId);
        mClient.deleteMessages(convId, messageIds, new StatusListener() {
            @Override
            public void onSuccess() {
                callback.invoke(true, 0, "Success");
            }

            @Override
            public void onError(StringeeError error) {
                callback.invoke(false, error.getCode(), error.getMessage());
            }
        });
    }

    @ReactMethod
    public void markConversationAsRead(String convId, final Callback callback) {
        if (mClient == null) {
            callback.invoke(false, -1, "StringeeClient is not initialized or connected");
            return;
        }

        mClient.getConversation(convId, new CallbackListener<Conversation>() {
            @Override
            public void onSuccess(Conversation conversation) {
                Message message = conversation.getLastMessage(mContext);
                if (message != null) {
                    message.markAsRead(mClient, new StatusListener() {
                        @Override
                        public void onSuccess() {
                            callback.invoke(true, 0, "Success");
                        }

                        @Override
                        public void onError(StringeeError error) {
                            callback.invoke(false, error.getCode(), error.getMessage());
                        }
                    });
                }
            }
        });
    }

    @ReactMethod
    public void getUser(String userId, Callback callback) {
        if (mClient == null) {
            callback.invoke(false, -1, "StringeeClient is not initialized");
            return;
        }

        User user = mClient.getUser(userId);
        if (user != null) {
            WritableMap param = Arguments.createMap();
            param.putString("userId", user.getUserId());
            param.putString("name", user.getName());
            param.putString("avatar", user.getAvatarUrl());
            callback.invoke(true, 0, "Success", param);
        } else {
            callback.invoke(false, -1, "User does not exist.");
        }
    }

    @Override
    public void onChangeEvent(StringeeChange stringeeChange) {
        if (contains(jsEvents, "onChangeEvent")) {
            WritableMap params = Arguments.createMap();
            StringeeObject.Type objectType = stringeeChange.getObjectType();
            params.putInt("objectType", objectType.getValue());
            params.putInt("changeType", stringeeChange.getChangeType().getValue());
            WritableArray objects = Arguments.createArray();
            WritableMap object = Arguments.createMap();
            if (objectType == StringeeObject.Type.CONVERSATION) {
                Conversation conversation = (Conversation) stringeeChange.getObject();
                object.putString("id", conversation.getId());
                object.putString("localId", conversation.getLocalId());
                object.putString("name", conversation.getName());
                object.putBoolean("isGroup", conversation.isGroup());
                object.putDouble("updatedAt", conversation.getUpdateAt());
                object.putString("lastMsgSender", conversation.getLastMsgSender());
                object.putInt("lastMsgType", conversation.getLastMsgType());
                object.putInt("unreadCount", conversation.getTotalUnread());
                object.putString("lastMsgId", conversation.getLastMsgId());
                object.putString("creator", conversation.getCreator());
                object.putDouble("created", conversation.getCreateAt());
                object.putDouble("lastMsgSeq", conversation.getLastMsgSeqReceived());
                object.putDouble("lastMsgCreatedAt", conversation.getLastTimeNewMsg());
                object.putInt("lastMsgState", conversation.getLastMsgState());
                if (conversation.getLastMsg() != null) {
                    try {
                        Bundle bundle = jsonToBundle(conversation.getLastMsg());
                        WritableMap lastMsgMap = Arguments.fromBundle(bundle);
                        object.putMap("text", lastMsgMap);
                    } catch (JSONException e) {
                        e.printStackTrace();
                    }
                }

                List<User> participants = conversation.getParticipants();
                WritableArray participantsMap = Arguments.createArray();
                for (int i = 0; i < participants.size(); i++) {
                    User user = participants.get(i);
                    WritableMap userMap = Arguments.createMap();
                    userMap.putString("userId", user.getUserId());
                    userMap.putString("name", user.getName());
                    userMap.putString("avatar", user.getAvatarUrl());
                    participantsMap.pushMap(userMap);
                }
                object.putArray("participants", participantsMap);
            } else if (objectType == StringeeObject.Type.MESSAGE) {
                Message message = (Message) stringeeChange.getObject();
                object.putString("id", message.getId());
                object.putString("localId", message.getLocalId());
                object.putString("conversationId", message.getConversationId());
                object.putDouble("createdAt", message.getCreatedAt());
                object.putInt("state", message.getState().getValue());
                object.putDouble("sequence", message.getSequence());
                object.putInt("type", message.getType());
                WritableMap contentMap = Arguments.createMap();
                switch (message.getType()) {
                    case 1:
                        contentMap.putString("content", message.getText());
                        break;
                    case 2:
                        WritableMap photoMap = Arguments.createMap();
                        photoMap.putString("filePath", message.getFileUrl());
                        photoMap.putString("thumbnail", message.getThumbnailUrl());
                        photoMap.putDouble("ratio", message.getImageRatio());
                        contentMap.putMap("photo", photoMap);
                        break;
                    case 3:
                        WritableMap videoMap = Arguments.createMap();
                        videoMap.putString("filePath", message.getFileUrl());
                        videoMap.putString("thumbnail", message.getThumbnailUrl());
                        videoMap.putDouble("ratio", message.getImageRatio());
                        videoMap.putInt("duration", message.getDuration());
                        contentMap.putMap("video", videoMap);
                        break;
                    case 4:
                        WritableMap audioMap = Arguments.createMap();
                        audioMap.putString("filePath", message.getFileUrl());
                        audioMap.putInt("duration", message.getDuration());
                        contentMap.putMap("audio", audioMap);
                        break;
                    case 5:
                        WritableMap fileMap = Arguments.createMap();
                        fileMap.putString("filePath", message.getFileUrl());
                        fileMap.putString("filename", message.getFileName());
                        fileMap.putDouble("length", message.getFileLength());
                        contentMap.putMap("file", fileMap);
                        break;
                    case 7:
                        try {
                            contentMap = Arguments.fromBundle(jsonToBundle(message.getText()));
                        } catch (JSONException e) {
                            e.printStackTrace();
                        }
                        break;
                    case 9:
                        WritableMap locationMap = Arguments.createMap();
                        locationMap.putDouble("lat", message.getLatitude());
                        locationMap.putDouble("lon", message.getLongitude());
                        contentMap.putMap("location", locationMap);
                        break;
                    case 10:
                        WritableMap contactMap = Arguments.createMap();
                        contactMap.putString("vcard", message.getContact());
                        contentMap.putMap("contact", contactMap);
                        break;
                    case 11:
                        WritableMap stickerMap = Arguments.createMap();
                        stickerMap.putString("name", message.getStickerName());
                        stickerMap.putString("category", message.getStickerCategory());
                        contentMap.putMap("sticker", stickerMap);
                        break;
                    case 100:
                        try {
                            contentMap = Arguments.fromBundle(jsonToBundle(message.getText()));
                        } catch (JSONException e) {
                            e.printStackTrace();
                        }
                        break;
                }
                object.putMap("content", contentMap);
                String senderId = message.getSenderId();
                User user = mClient.getUser(senderId);
                String name = "";
                if (user != null) {
                    name = user.getName();
                    if (name == null || name.length() == 0) {
                        name = user.getUserId();
                    }
                }
                object.putString("sender", name);
            }
            objects.pushMap(object);
            params.putArray("objects", objects);
            sendEvent(getReactApplicationContext(), "onChangeEvent", params);
        }
    }

    @ReactMethod
    public void clearDb(Callback callback) {
        if (mClient == null) {
            callback.invoke(false, -1, "StringeeClient is not initialized");
            return;
        }
        mClient.clearDb();
        callback.invoke(true, 0, "Success");
    }

    @ReactMethod
    public void updateConversation(String convId, ReadableMap convMap, final Callback callback) {
        if (mClient == null) {
            callback.invoke(false, -1, "StringeeClient is not initialized");
            return;
        }

        if (convId == null) {
            callback.invoke(false, -2, "Conversation id can not be null");
            return;
        }

        String name = "";
        if (convMap.hasKey("name")) {
            name = convMap.getString("name");
        }
        String avatar = "";
        if (convMap.hasKey("avatar")) {
            avatar = convMap.getString("avatar");
        }

        final String finalAvatar = avatar;
        final String finalName = name;
        mClient.getConversation(convId, new CallbackListener<Conversation>() {
            @Override
            public void onSuccess(Conversation conversation) {
                conversation.updateConversation(mClient, finalName, finalAvatar, new StatusListener() {
                    @Override
                    public void onSuccess() {
                        callback.invoke(true, 0, "Success");
                    }

                    @Override
                    public void onError(StringeeError error) {
                        callback.invoke(false, error.getCode(), error.getMessage());
                    }
                });
            }

            @Override
            public void onError(StringeeError error) {
                callback.invoke(false, error.getCode(), error.getMessage());
            }
        });
    }

    @ReactMethod
    public void getConversationWithUser(String userId, final Callback callback) {
        if (mClient == null) {
            callback.invoke(false, -1, "StringeeClient is not initialized");
            return;
        }

        if (userId == null) {
            callback.invoke(false, -2, "User id can not be null");
            return;
        }

        mClient.getConversationByUserId(userId, new CallbackListener<Conversation>() {
            @Override
            public void onSuccess(Conversation conversation) {
                WritableMap params = Arguments.createMap();
                params.putString("id", conversation.getId());
                params.putString("localId", conversation.getLocalId());
                params.putString("name", conversation.getName());
                params.putBoolean("isDistinct", conversation.isDistinct());
                params.putBoolean("isGroup", conversation.isGroup());
                params.putDouble("updatedAt", conversation.getUpdateAt());
                params.putString("lastMsgSender", conversation.getLastMsgSender());
                params.putString("text", conversation.getText());
                params.putInt("lastMsgType", conversation.getLastMsgType());
                params.putInt("unreadCount", conversation.getTotalUnread());
                params.putString("lastMsgId", conversation.getLastMsgId());
                params.putString("creator", conversation.getCreator());
                params.putDouble("created", conversation.getCreateAt());
                params.putDouble("lastMsgSeq", conversation.getLastMsgSeqReceived());
                params.putDouble("lastMsgCreatedAt", conversation.getLastTimeNewMsg());
                params.putInt("lastMsgState", conversation.getLastMsgState());
                if (conversation.getLastMsg() != null) {
                    try {
                        Bundle bundle = jsonToBundle(conversation.getLastMsg());
                        WritableMap lastMsgMap = Arguments.fromBundle(bundle);
                        params.putMap("text", lastMsgMap);
                    } catch (JSONException e) {
                        e.printStackTrace();
                    }
                }
                List<User> participants = conversation.getParticipants();
                WritableArray participantsMap = Arguments.createArray();
                for (int i = 0; i < participants.size(); i++) {
                    User user = participants.get(i);
                    WritableMap userMap = Arguments.createMap();
                    userMap.putString("userId", user.getUserId());
                    userMap.putString("name", user.getName());
                    userMap.putString("avatar", user.getAvatarUrl());
                    participantsMap.pushMap(userMap);
                }
                params.putArray("participants", participantsMap);
                callback.invoke(true, 0, "Success", params);
            }

            @Override
            public void onError(StringeeError error) {
                callback.invoke(false, error.getCode(), error.getMessage());
            }
        });
    }

    @ReactMethod
    public void getUnreadConversationCount(final Callback callback) {
        if (mClient == null) {
            callback.invoke(false, -1, "StringeeClient is not initialized");
            return;
        }

        mClient.getTotalUnread(new CallbackListener<Integer>() {
            @Override
            public void onSuccess(Integer count) {
                callback.invoke(true, 0, "Success", count);
            }

            @Override
            public void onError(StringeeError error) {
                callback.invoke(false, error.getCode(), error.getMessage());
            }
        });
    }

    private Bundle jsonToBundle(String text) throws JSONException {
        JSONObject jsonObject = new JSONObject(text);
        Bundle bundle = new Bundle();
        Iterator iter = jsonObject.keys();
        while (iter.hasNext()) {
            String key = (String) iter.next();
            String value = jsonObject.getString(key);
            bundle.putString(key, value);
        }
        return bundle;
    }
}

