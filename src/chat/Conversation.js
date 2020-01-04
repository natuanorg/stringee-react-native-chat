import User from './User';

class Conversation {
    constructor(props) {
        this.id = props.id;
        this.name = props.name;
        this.isGroup = props.isGroup;
        this.updatedAt = props.updatedAt;
        this.lastMsgSender = props.lastMsgSender;
        this.lastMsgContent = props.text;
        this.lastMsgType = props.lastMsgType;
        this.unreadCount = props.unreadCount;
        this.lastMsgId = props.lastMsgId;
        this.creator = props.creator;
        this.created = props.created;
        this.lastMsgSeq = props.lastMsgSeq;
        this.lastMsgCreatedAt = props.lastMsgCreatedAt;

        var parts = [];
        var tempParts = props.participants;
        tempParts.map((part) => {
            var user = new User(part);
            parts.push(user);
        });

        this.participants = parts;
    }
}

export default Conversation;