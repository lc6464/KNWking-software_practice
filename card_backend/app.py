import os
import json
from flask import Flask, request, jsonify, send_from_directory
from flask_sqlalchemy import SQLAlchemy
from flask_cors import CORS
from werkzeug.utils import secure_filename
from datetime import datetime

app = Flask(__name__)
CORS(app)

BASE_DIR = os.path.abspath(os.path.dirname(__file__))
UPLOAD_FOLDER = os.path.join(BASE_DIR, 'uploads')
if not os.path.exists(UPLOAD_FOLDER):
    os.makedirs(UPLOAD_FOLDER)

app.config['SQLALCHEMY_DATABASE_URI'] = 'sqlite:///' + os.path.join(BASE_DIR, 'cards.db')
app.config['SQLALCHEMY_TRACK_MODIFICATIONS'] = False
app.config['UPLOAD_FOLDER'] = UPLOAD_FOLDER

db = SQLAlchemy(app)


# === 数据模型 ===
class Card(db.Model):
    id = db.Column(db.Integer, primary_key=True)
    title = db.Column(db.String(100), nullable=False)
    content = db.Column(db.Text, nullable=True)  # 支持 Markdown 文本
    images_json = db.Column(db.Text, default='[]')

    group_name = db.Column(db.String(50), default='默认清单')
    tags = db.Column(db.String(200), default='')
    is_marked = db.Column(db.Boolean, default=False)

    # === 新增：完成状态 ===
    is_completed = db.Column(db.Boolean, default=False)

    created_at = db.Column(db.DateTime, default=datetime.now)
    reminder_type = db.Column(db.String(20), default='none')
    reminder_value = db.Column(db.String(50), default='')
    last_reviewed = db.Column(db.DateTime, default=datetime.now)

    def to_dict(self):
        try:
            filenames = json.loads(self.images_json)
        except:
            filenames = []
        img_urls = [f"{request.host_url}uploads/{fn}" for fn in filenames]
        return {
            'id': self.id,
            'title': self.title,
            'content': self.content,
            'image_urls': img_urls,
            'group_name': self.group_name,
            'tags': self.tags,
            'is_marked': self.is_marked,
            'is_completed': self.is_completed,  # 返回给前端
            'created_at': self.created_at.isoformat(),
            'reminder_type': self.reminder_type,
            'reminder_value': self.reminder_value,
            'last_reviewed': self.last_reviewed.isoformat() if self.last_reviewed else None
        }


class MetaData(db.Model):
    id = db.Column(db.Integer, primary_key=True)
    groups_json = db.Column(db.Text, default='["默认清单", "工作", "生活"]')
    tags_json = db.Column(db.Text, default='["高优先级", "中优先级", "低优先级"]')


def delete_card_logic(card):
    try:
        filenames = json.loads(card.images_json)
        for fn in filenames:
            file_path = os.path.join(app.config['UPLOAD_FOLDER'], fn)
            if os.path.exists(file_path):
                os.remove(file_path)
    except Exception as e:
        print(f"Error deleting files: {e}")
    db.session.delete(card)


def get_or_create_meta():
    meta = MetaData.query.first()
    if not meta:
        meta = MetaData()
        db.session.add(meta)
        db.session.commit()
    return meta


# === 接口 ===
@app.route('/api/meta', methods=['GET'])
def get_meta():
    meta = get_or_create_meta()
    return jsonify({'groups': json.loads(meta.groups_json), 'tags': json.loads(meta.tags_json)})


@app.route('/api/meta', methods=['POST'])
def update_meta():
    meta = get_or_create_meta()
    data = request.json
    if 'groups' in data: meta.groups_json = json.dumps(data['groups'])
    if 'tags' in data: meta.tags_json = json.dumps(data['tags'])
    db.session.commit()
    return jsonify({'message': 'Updated'})


@app.route('/api/meta/delete_group', methods=['POST'])
def delete_group_api():
    target_group = request.json.get('name')
    if not target_group: return jsonify({'error': 'Missing name'}), 400
    cards = Card.query.filter_by(group_name=target_group).all()
    for c in cards: delete_card_logic(c)
    meta = get_or_create_meta()
    groups = json.loads(meta.groups_json)
    if target_group in groups:
        groups.remove(target_group)
        meta.groups_json = json.dumps(groups)
    db.session.commit()
    return jsonify({'message': 'Group deleted'})


@app.route('/api/meta/delete_tag', methods=['POST'])
def delete_tag_api():
    target_tag = request.json.get('name')
    if not target_tag: return jsonify({'error': 'Missing name'}), 400
    all_cards = Card.query.all()
    for c in all_cards:
        if not c.tags: continue
        tag_list = c.tags.split(',')
        if target_tag in tag_list:
            tag_list.remove(target_tag)
            c.tags = ','.join(tag_list)
    meta = get_or_create_meta()
    tags = json.loads(meta.tags_json)
    if target_tag in tags:
        tags.remove(target_tag)
        meta.tags_json = json.dumps(tags)
    db.session.commit()
    return jsonify({'message': 'Tag deleted'})


@app.route('/api/upload', methods=['POST'])
def upload_file():
    if 'file' not in request.files: return jsonify({'error': 'No file part'}), 400
    file = request.files['file']
    if file.filename == '': return jsonify({'error': 'No selected file'}), 400
    if file:
        timestamp = datetime.now().strftime('%Y%m%d%H%M%S%f')
        filename = secure_filename(f"{timestamp}_{file.filename}")
        file.save(os.path.join(app.config['UPLOAD_FOLDER'], filename))
        return jsonify({'filename': filename})
    return jsonify({'error': 'Upload failed'}), 500


@app.route('/uploads/<filename>')
def uploaded_file(filename):
    return send_from_directory(app.config['UPLOAD_FOLDER'], filename)


@app.route('/api/cards', methods=['GET'])
def get_cards():
    cards = Card.query.all()
    return jsonify([c.to_dict() for c in reversed(cards)])


@app.route('/api/cards', methods=['POST'])
def create_card():
    data = request.json
    new_card = Card(
        title=data.get('title'),
        content=data.get('content', ''),
        images_json=json.dumps(data.get('image_paths', [])),
        group_name=data.get('group_name', '默认清单'),
        tags=data.get('tags', ''),
        is_marked=data.get('is_marked', False),
        is_completed=data.get('is_completed', False),  # 接收完成状态
        created_at=datetime.now(),
        reminder_type=data.get('reminder_type', 'none'),
        reminder_value=data.get('reminder_value', ''),
        last_reviewed=datetime.now()
    )
    db.session.add(new_card)
    db.session.commit()
    return jsonify(new_card.to_dict()), 201


@app.route('/api/cards/<int:id>', methods=['PUT'])
def update_card(id):
    card = Card.query.get_or_404(id)
    data = request.json
    card.title = data.get('title', card.title)
    card.content = data.get('content', card.content)
    if 'image_paths' in data:
        card.images_json = json.dumps(data['image_paths'])
    card.group_name = data.get('group_name', card.group_name)
    card.tags = data.get('tags', card.tags)
    card.is_marked = data.get('is_marked', card.is_marked)
    card.is_completed = data.get('is_completed', card.is_completed)  # 更新完成状态
    card.reminder_type = data.get('reminder_type', card.reminder_type)
    card.reminder_value = data.get('reminder_value', card.reminder_value)
    card.last_reviewed = datetime.now()
    db.session.commit()
    return jsonify(card.to_dict())


@app.route('/api/cards/<int:id>', methods=['DELETE'])
def delete_card(id):
    card = Card.query.get_or_404(id)
    delete_card_logic(card)
    db.session.commit()
    return jsonify({'message': 'Deleted'})


if __name__ == '__main__':
    with app.app_context():
        db.create_all()
    app.run(debug=True, host='0.0.0.0', port=5000)