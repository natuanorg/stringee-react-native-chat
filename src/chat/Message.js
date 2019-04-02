
class Message {
    constructor(props) {
        this.id = props.id;
        this.conversationId = props.conversationId;
        this.sender = props.sender;
        this.createdAt = props.createdAt;
        this.state = props.state;
        this.sequence = props.sequence;
        this.type = props.type;
        this.text = props.text;
    }
}

export default Message;