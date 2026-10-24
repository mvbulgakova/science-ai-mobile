#!/data/data/com.termux/files/usr/bin/bash
PROMPT="$*"
if [ -z "$PROMPT" ]; then
    termux-notification --title "🧠 Science AI" --content "Скопируй текст и запусти снова, или напиши: ./ai.sh 'твой вопрос'"
    exit 1
fi

if echo "$PROMPT" | grep -iE "интеграл|формула|реши|уравнение|производная|latex|матриц|sqrt|сумма|теорем|геометр|integral|derivative|equation|докажи|вычисли" > /dev/null; then
    MODEL_NAME="DeepSeek Math"
    MODEL_PATH="$HOME/science-ai/models/deepseek-math-7b.gguf"
    PORT=8081
    TEMP=0.1
else
    MODEL_NAME="Qwen 2.5 7B"
    MODEL_PATH="$HOME/science-ai/models/Qwen2.5-7B-Instruct-Q4_K_M.gguf"
    PORT=8080
    TEMP=0.7
fi

if ! curl -s http://127.0.0.1:$PORT/health | grep -q '"status":"ok"'; then
    termux-notification --title "⏳ Science AI" --content "Загружаю $MODEL_NAME в память..."
    pkill -f "llama-server"
    sleep 2
    nohup ~/llama.cpp/build/bin/llama-server -m "$MODEL_PATH" -t 4 -c 4096 --host 127.0.0.1 --port $PORT --temp $TEMP > ~/science-ai/server.log 2>&1 &
    for i in {1..40}; do
        if curl -s http://127.0.0.1:$PORT/health | grep -q '"status":"ok"'; then break; fi
        sleep 1
    done
fi

RESULT=$(curl -s http://127.0.0.1:$PORT/completion -H "Content-Type: application/json" -d "{\"prompt\": \"<s>[INST] $PROMPT [/INST]\", \"n_predict\": 1000, \"temperature\": $TEMP}" | python3 -c "import sys, json; print(json.load(sys.stdin)['content'].replace('\\n', '\n'))")

termux-notification --title "✅ Ответ ($MODEL_NAME)" --content "$RESULT"
