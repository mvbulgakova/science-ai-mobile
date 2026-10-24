#!/data/data/com.termux/files/usr/bin/bash
echo "🚀 Начинаю установку Science AI Mobile..."

# Обновляем пакеты
pkg update -y && pkg upgrade -y
pkg install -y cmake clang make git wget curl python termux-api

# Клонируем и собираем llama.cpp
cd ~
if [ ! -d "llama.cpp" ]; then
    git clone https://github.com/ggerganov/llama.cpp.git
    cd llama.cpp
    cmake -B build
    cmake --build build --config Release -j8
else
    echo "✅ llama.cpp уже установлен"
fi

# Создаём папку для моделей
mkdir -p ~/science-ai/models

# Скачиваем модели (если их нет)
cd ~/science-ai/models
if [ ! -f "Qwen2.5-7B-Instruct-Q4_K_M.gguf" ]; then
    echo "⏳ Скачиваю Qwen 2.5 7B (4.4 ГБ)..."
    wget --user-agent="Mozilla/5.0" -O Qwen2.5-7B-Instruct-Q4_K_M.gguf "https://huggingface.co/bartowski/Qwen2.5-7B-Instruct-GGUF/resolve/main/Qwen2.5-7B-Instruct-Q4_K_M.gguf"
fi

if [ ! -f "deepseek-math-7b.gguf" ]; then
    echo "⏳ Скачиваю DeepSeek Math 7B (4.4 ГБ)..."
    wget --user-agent="Mozilla/5.0" -O deepseek-math-7b.gguf "https://huggingface.co/bartowski/MathCoder2-DeepSeekMath-7B-GGUF/resolve/main/MathCoder2-DeepSeekMath-7B-Q4_K_M.gguf"
fi

echo "✅ Установка завершена! Теперь настрой MacroDroid или используй ./ai.sh"EOF
chmod +x setup.sh

# 3. Создаём умный маршрутизатор (ai.sh)
cat > ai.sh << 'EOF'
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
