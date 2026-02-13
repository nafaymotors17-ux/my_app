"""
Phishing Detection Backend
A simple Flask server for analyzing SMS and WhatsApp messages for phishing indicators.
This is a template - you should implement proper ML models in production.

To run:
    pip install -r requirements.txt
    python phishing_backend.py

For production with Gunicorn:
    gunicorn -b 0.0.0.0:5000 --timeout 30 phishing_backend:app
"""

from flask import Flask, request, jsonify
from flask_cors import CORS
import re
from typing import Dict, List, Tuple
import logging
from datetime import datetime

# Configure logging
logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

app = Flask(__name__)
CORS(app)

class PhishingPattern:
    """Pattern matching for common phishing indicators"""
    
    PATTERNS = {
        # Urgency/Action Required
        'urgency': {
            'patterns': [
                r'\burge|urgent|immediate action|act now|asap|verify\s+(?:account|identity|info)|confirm\s+(?:details|account)|click\s+here|update\s+(?:payment|info)',
            ],
            'weight': 0.25,
            'keywords': ['urgent', 'verify', 'confirm', 'action required', 'click here', 'act now']
        },
        
        # Financial/Sensitive Information
        'financial': {
            'patterns': [
                r'\b(?:bank|credit|card|debit|payment|transaction|account|password|pin|cvv|ssn|tax|refund)\b',
                r'(?:update|verify|confirm)\s+(?:payment|banking|card)',
            ],
            'weight': 0.20,
            'keywords': ['bank', 'credit card', 'payment', 'account', 'password']
        },
        
        # Suspicious Links
        'links': {
            'patterns': [
                r'https?://[^\s]+\.(com|net|org|tk|ml)',
                r'\bit\.(?:co|cc|xyz|uk)',
                r'(?:bit\.ly|tinyurl|short\.link|goo\.gl)',
            ],
            'weight': 0.15,
            'keywords': ['shortener', 'bit.ly', 'http', 'link']
        },
        
        # Account/Login Indicators
        'account': {
            'patterns': [
                r'\b(?:login|sign\s+in|password|reset|forgot|reactivate|re-activate|unlock|suspended|locked|disabled)\b',
                r'(?:verify|confirm)\s+(?:account|identity|credentials)',
            ],
            'weight': 0.20,
            'keywords': ['login', 'password', 'account', 'verify']
        },
        
        # Suspicious Activity
        'suspicious': {
            'patterns': [
                r'\b(?:suspicious|unusual|unauthorized|compromise|hacked|breach|fraud|stolen|unusual.*activity)\b',
            ],
            'weight': 0.15,
            'keywords': ['suspicious', 'unauthorized', 'fraud', 'hacked']
        },
        
        # Prizes/Rewards/Too Good to Be True
        'prize': {
            'patterns': [
                r'\b(?:congratulations|won|claim.*prize|free.*(?:money|gift|iphone)|lucky.*(?:winner|selected)|reward)\b',
            ],
            'weight': 0.18,
            'keywords': ['congratulations', 'won', 'claim', 'free']
        },
        
        # Sender Spoofing Indicators
        'spoofing': {
            'patterns': [
                r'(?:from|this is from|message from)\s+(?:your\s+)?(?:bank|paypal|apple|google|amazon)',
            ],
            'weight': 0.20,
            'keywords': ['from your bank', 'paypal', 'apple', 'amazon']
        }
    }
    
    @staticmethod
    def analyze(text: str) -> Tuple[float, List[str]]:
        """
        Analyze text for phishing patterns
        Returns: (risk_score, detected_patterns)
        """
        if not text:
            return 0.0, []
        
        text_lower = text.lower()
        risk_score = 0.0
        detected = []
        
        # Check each pattern category
        for category, info in PhishingPattern.PATTERNS.items():
            matched = False
            for pattern in info['patterns']:
                if re.search(pattern, text_lower, re.IGNORECASE):
                    risk_score += info['weight']
                    matched = True
                    break
            
            if matched:
                detected.append(category)
        
        # Cap risk score at 1.0
        risk_score = min(1.0, risk_score)
        
        return risk_score, detected


class PhishingClassifier:
    """Classify messages based on risk score"""
    
    @staticmethod
    def classify(risk_score: float) -> str:
        """
        Classify message based on risk score
        Returns: 'safe', 'suspicious', or 'phishing'
        """
        if risk_score > 0.70:
            return 'phishing'
        elif risk_score > 0.40:
            return 'suspicious'
        else:
            return 'safe'


# ============================================================================
# API Endpoints
# ============================================================================

@app.route('/health', methods=['GET'])
def health():
    """
    Health check endpoint
    Returns: Server status
    """
    try:
        return jsonify({
            'status': 'healthy',
            'timestamp': datetime.now().isoformat(),
            'version': '1.0.0'
        }), 200
    except Exception as e:
        logger.error(f"Health check error: {str(e)}")
        return jsonify({'status': 'unhealthy', 'error': str(e)}), 500


@app.route('/analyze/sms', methods=['POST'])
def analyze_sms():
    """
    Analyze SMS message for phishing indicators
    
    Request JSON:
    {
        "message": "Click here to verify your account",
        "sender": "+1234567890",
        "phone_number": "+9876543210",  # Optional - your phone number
        "timestamp": "2024-02-13T10:30:00Z"  # Optional
    }
    
    Response JSON:
    {
        "message_id": "2024-02-13T10:30:00Z",
        "risk_score": 0.75,
        "risk_percentage": 75,
        "classification": "suspicious",
        "details": {
            "message_length": 45,
            "has_urls": false,
            "sender": "+1234567890",
            "language": "en"
        },
        "detected_patterns": ["urgency", "account"],
        "confidence": 0.92
    }
    """
    try:
        data = request.json
        message = data.get('message', '').strip()
        sender = data.get('sender', 'Unknown')
        message_id = data.get('timestamp', datetime.now().isoformat())
        
        if not message:
            return jsonify({
                'error': 'Message is required',
                'message_id': message_id
            }), 400
        
        # Analyze message
        risk_score, detected_patterns = PhishingPattern.analyze(message)
        classification = PhishingClassifier.classify(risk_score)
        
        response = {
            'message_id': message_id,
            'risk_score': round(risk_score, 3),
            'risk_percentage': int(risk_score * 100),
            'classification': classification,
            'details': {
                'message_length': len(message),
                'has_urls': bool(re.search(r'https?://', message)),
                'sender': sender,
                'type': 'sms',
                'analyzed_at': datetime.now().isoformat()
            },
            'detected_patterns': detected_patterns,
            'confidence': round(min(1.0, risk_score + 0.15), 2)  # Confidence metric
        }
        
        logger.info(f"SMS analyzed: {classification} (score: {risk_score:.2f}) from {sender}")
        return jsonify(response), 200
        
    except Exception as e:
        logger.error(f"Error analyzing SMS: {str(e)}")
        return jsonify({'error': str(e), 'status': 'error'}), 500


@app.route('/analyze/whatsapp', methods=['POST'])
def analyze_whatsapp():
    """
    Analyze WhatsApp message for phishing indicators
    
    Request JSON:
    {
        "message": "Verify your WhatsApp account",
        "sender": "+1234567890",
        "timestamp": "2024-02-13T10:30:00Z"  # Optional
    }
    
    Response: Same as /analyze/sms but with type: 'whatsapp'
    """
    try:
        data = request.json
        message = data.get('message', '').strip()
        sender = data.get('sender', 'Unknown')
        message_id = data.get('timestamp', datetime.now().isoformat())
        
        if not message:
            return jsonify({
                'error': 'Message is required',
                'message_id': message_id
            }), 400
        
        # Analyze message
        risk_score, detected_patterns = PhishingPattern.analyze(message)
        classification = PhishingClassifier.classify(risk_score)
        
        response = {
            'message_id': message_id,
            'risk_score': round(risk_score, 3),
            'risk_percentage': int(risk_score * 100),
            'classification': classification,
            'details': {
                'message_length': len(message),
                'has_urls': bool(re.search(r'https?://', message)),
                'sender': sender,
                'type': 'whatsapp',
                'analyzed_at': datetime.now().isoformat()
            },
            'detected_patterns': detected_patterns,
            'confidence': round(min(1.0, risk_score + 0.15), 2)
        }
        
        logger.info(f"WhatsApp analyzed: {classification} (score: {risk_score:.2f}) from {sender}")
        return jsonify(response), 200
        
    except Exception as e:
        logger.error(f"Error analyzing WhatsApp message: {str(e)}")
        return jsonify({'error': str(e), 'status': 'error'}), 500


@app.route('/analyze/batch', methods=['POST'])
def batch_analyze():
    """
    Analyze multiple messages in bulk
    
    Request JSON:
    {
        "messages": [
            {
                "id": "msg_1",
                "message": "Click here to verify",
                "sender": "+1234567890"
            },
            {
                "id": "msg_2",
                "message": "Congratulations you won!",
                "sender": "+9876543210"
            }
        ],
        "timestamp": "2024-02-13T10:30:00Z"  # Optional
    }
    
    Response JSON:
    {
        "batch_id": "2024-02-13T10:30:00Z",
        "total_analyzed": 2,
        "results": [
            {
                "id": "msg_1",
                "message_id": "msg_1",
                "risk_score": 0.75,
                "classification": "suspicious"
            },
            {
                "id": "msg_2",
                "message_id": "msg_2",
                "risk_score": 0.45,
                "classification": "suspicious"
            }
        ]
    }
    """
    try:
        data = request.json
        messages = data.get('messages', [])
        batch_id = data.get('timestamp', datetime.now().isoformat())
        
        if not messages:
            return jsonify({
                'error': 'Messages array is required',
                'batch_id': batch_id
            }), 400
        
        results = []
        for message_data in messages:
            msg_text = message_data.get('message', '').strip()
            msg_id = message_data.get('id', '')
            
            if not msg_text:
                continue
            
            risk_score, detected_patterns = PhishingPattern.analyze(msg_text)
            classification = PhishingClassifier.classify(risk_score)
            
            results.append({
                'id': msg_id,
                'message_id': msg_id,
                'risk_score': round(risk_score, 3),
                'risk_percentage': int(risk_score * 100),
                'classification': classification,
                'detected_patterns': detected_patterns
            })
        
        response = {
            'batch_id': batch_id,
            'total_analyzed': len(results),
            'results': results,
            'analyzed_at': datetime.now().isoformat()
        }
        
        logger.info(f"Batch analysis completed: {len(results)} messages")
        return jsonify(response), 200
        
    except Exception as e:
        logger.error(f"Batch analysis error: {str(e)}")
        return jsonify({'error': str(e), 'status': 'error'}), 500


@app.route('/patterns', methods=['GET'])
def get_patterns():
    """
    Get list of phishing patterns detected by the system
    Useful for client-side pattern matching and UI information
    """
    try:
        patterns = {}
        for category, info in PhishingPattern.PATTERNS.items():
            patterns[category] = {
                'weight': info['weight'],
                'keywords': info['keywords']
            }
        
        return jsonify({
            'total_categories': len(patterns),
            'patterns': patterns
        }), 200
    except Exception as e:
        logger.error(f"Error getting patterns: {str(e)}")
        return jsonify({'error': str(e)}), 500


@app.route('/stats', methods=['GET'])
def get_stats():
    """
    Get backend statistics and information
    """
    try:
        return jsonify({
            'status': 'operational',
            'version': '1.0.0',
            'endpoints': [
                '/health',
                '/analyze/sms',
                '/analyze/whatsapp',
                '/analyze/batch',
                '/patterns',
                '/stats'
            ],
            'max_message_length': 10000,
            'batch_max_size': 100,
            'timestamp': datetime.now().isoformat()
        }), 200
    except Exception as e:
        logger.error(f"Error getting stats: {str(e)}")
        return jsonify({'error': str(e)}), 500


# ============================================================================
# Error Handlers
# ============================================================================

@app.errorhandler(404)
def not_found(error):
    """Handle 404 errors"""
    return jsonify({
        'error': 'Endpoint not found',
        'status': 404,
        'available_endpoints': [
            '/health',
            '/analyze/sms',
            '/analyze/whatsapp',
            '/analyze/batch',
            '/patterns',
            '/stats'
        ]
    }), 404


@app.errorhandler(405)
def method_not_allowed(error):
    """Handle 405 errors"""
    return jsonify({
        'error': 'Method not allowed',
        'status': 405
    }), 405


@app.errorhandler(500)
def internal_error(error):
    """Handle 500 errors"""
    logger.error(f"Internal server error: {str(error)}")
    return jsonify({
        'error': 'Internal server error',
        'status': 500
    }), 500


# ============================================================================
# Main
# ============================================================================

if __name__ == '__main__':
    logger.info("Starting Phishing Detection Backend Server")
    logger.info("Available at http://0.0.0.0:5000")
    
    # For development only
    app.run(
        host='0.0.0.0',
        port=5000,
        debug=True,
        threaded=True
    )
