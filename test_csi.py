import numpy as np
from sklearn.model_selection import train_test_split
from sklearn.ensemble import RandomForestClassifier
from sklearn.metrics import accuracy_score

# 가상의 CSI 데이터 생성 함수 (실제로는 CSI 캡처 툴로 데이터를 수집해야 함)
def generate_dummy_csi_data(num_samples, num_subcarriers=56):
    """
    가상의 CSI 데이터를 생성합니다.
    Args:
        num_samples (int): 생성할 데이터 샘플 수.
        num_subcarriers (int): CSI 서브캐리어 수.
    Returns:
        tuple: (CSI 데이터, 위치 라벨)
    """
    locations = ['A', 'B', 'C', 'D']
    X = []
    y = []

    for _ in range(num_samples):
        location = np.random.choice(locations)
        
        # 위치에 따라 CSI 데이터에 약간의 패턴을 부여
        if location == 'A':
            csi_data = np.random.normal(loc=10, scale=2, size=num_subcarriers)
        elif location == 'B':
            csi_data = np.random.normal(loc=15, scale=2, size=num_subcarriers)
        elif location == 'C':
            csi_data = np.random.normal(loc=20, scale=2, size=num_subcarriers)
        else:
            csi_data = np.random.normal(loc=25, scale=2, size=num_subcarriers)

        X.append(csi_data)
        y.append(location)

    return np.array(X), np.array(y)

# CSI 데이터에서 특징 추출 함수
def extract_features(csi_data):
    """
    CSI 데이터에서 특징을 추출합니다.
    예시에서는 간단하게 각 샘플의 평균값을 특징으로 사용합니다.
    실제로는 더 복잡한 특징(AOA, TOF 등)을 사용해야 합니다.
    """
    return np.mean(csi_data, axis=1).reshape(-1, 1)

# 1. 데이터 생성 (실제로는 수집된 데이터를 로드)
print("1. CSI 데이터 생성...")
X_raw, y = generate_dummy_csi_data(num_samples=1000)

# 2. 특징 추출
print("2. CSI 데이터에서 특징 추출...")
X_features = extract_features(X_raw)

# 3. 학습 및 테스트 데이터셋 분리
print("3. 학습 및 테스트 데이터셋 분리...")
X_train, X_test, y_train, y_test = train_test_split(X_features, y, test_size=0.3, random_state=42)

# 4. 모델 학습 (랜덤 포레스트 분류기 사용)
print("4. 위치 추정 모델 학습...")
model = RandomForestClassifier(n_estimators=100, random_state=42)
model.fit(X_train, y_train)

# 5. 모델 평가
print("5. 학습된 모델로 위치 예측 및 평가...")
y_pred = model.predict(X_test)
accuracy = accuracy_score(y_test, y_pred)
print(f"모델 정확도: {accuracy:.2f}")

# 6. 새로운 CSI 데이터로 위치 예측
print("\n6. 새로운 CSI 데이터로 위치 예측 시뮬레이션...")
new_csi_data, _ = generate_dummy_csi_data(num_samples=5)
new_features = extract_features(new_csi_data)
predicted_locations = model.predict(new_features)

print("예측된 위치:", predicted_locations)