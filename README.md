# 🤖 Edge Vision — Detecção de Anomalias com Flutter + TensorFlow Lite

Este projeto é um **MVP (Minimum Viable Product)** de um sistema embarcado de **reconhecimento de anomalias em vídeo**, desenvolvido em **Flutter**, utilizando **TensorFlow Lite** e integração com serviços locais.  
O objetivo é permitir **detecção de comportamentos suspeitos ou eventos críticos em tempo real**, diretamente no dispositivo — **sem depender de conexão com a nuvem**.

---

## 🚀 Visão Geral

O **Edge Vision** foi criado para cenários de **monitoramento inteligente** e **segurança pública**, combinando:
- Processamento **on-device** com **LLM/IA embarcada**;
- Reconhecimento de padrões visuais por meio de **modelos MobileNet**;
- Comunicação com serviços locais via **eventos críticos**.

O sistema utiliza a câmera do dispositivo para capturar frames, processá-los por um modelo TFLite e identificar **anomalias** — como a presença de pessoas ou movimentações não esperadas — enviando eventos automáticos para o backend local.

---

<img width="320" height="100%" alt="Simulator Screenshot - iPhone 15 - 2025-11-06 at 10 55 29" src="https://github.com/user-attachments/assets/d77606a2-d59c-4c92-a4ea-e3a84b5d95b5" />
<img width="320" height="100%" alt="Screenshot_1763570880" src="https://github.com/user-attachments/assets/44d30e6c-d8a0-4b28-b78b-fa9a88a972cb" />


___

## 🧠 Tecnologias Utilizadas

| Camada | Tecnologia |
|--------|-------------|
| App Móvel | [Flutter](https://flutter.dev/) |
| Visão Computacional | [TensorFlow Lite](https://www.tensorflow.org/lite) |
| Processamento de Frames | [image](https://pub.dev/packages/image) |
| Hardware | [camera](https://pub.dev/packages/camera) |
| Backend Local | Event Service / API interna |
| LLM Local (em desenvolvimento) | Integração com modelos embarcados (ex: Mistral, Phi, Gemma) |

---

## ⚙️ Arquitetura

            +----------------------------------------------------------+
            |                      Flutter App                         |
            |                                                          |
            |  +----------------+       +----------------------------+  |
            |  |  Camera Stream |  ---> |  TensorFlow Lite Inference |  |
            |  +----------------+       +----------------------------+  |
            |             |                          |                 |
            |             v                          v                 |
            |     +----------------+        +-----------------------+  |
            |     | Image Processing|        | EventService Trigger |  |
            |     +----------------+        +-----------------------+  |
            |             |                          |                 |
            |             +------------> Logs & Alerts <---------------+
            |                                                          |
            +----------------------------------------------------------+


## 🧠 Modelo de IA

O modelo utilizado é o **MobileNet v1 (224x224)**, otimizado para dispositivos móveis.  
Ele realiza **inferências em tempo real**, com suporte a **multi-threading** e **delegado XNNPack** para ganho de performance.

### Configuração do Modelo
- Input Shape: `[1, 224, 224, 3]`
- Output Shape: `[1, 1001]`
- Framework: TensorFlow Lite
- Delegate: XNNPack (Android/iOS)
- Threading: 4 threads simultâneas

---

## 🧰 Instalação e Execução

### 1️⃣ Pré-requisitos
- Flutter SDK 3.0+
- Android Studio / VS Code
- Dispositivo físico com câmera
- Permissões de câmera concedidas




### 2️⃣ Clonar o repositório
```bash
git clone https://github.com/seuusuario/edge-vision.git
cd edge-vision


