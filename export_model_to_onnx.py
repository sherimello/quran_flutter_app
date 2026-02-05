"""
Export sentence-transformers model to ONNX format for Flutter.
Uses PyTorch (works on Python 3.14!) - NO TensorFlow needed.
Output: assets/models/sentence_encoder.onnx + vocab.txt
"""

import os
import torch
from sentence_transformers import SentenceTransformer
import numpy as np

def mean_pooling(model_output, attention_mask):
    """Mean Pooling - Take attention mask into account for correct averaging"""
    token_embeddings = model_output[0]
    input_mask_expanded = attention_mask.unsqueeze(-1).expand(token_embeddings.size()).float()
    return torch.sum(token_embeddings * input_mask_expanded, 1) / torch.clamp(input_mask_expanded.sum(1), min=1e-9)

class SentenceEncoderONNX(torch.nn.Module):
    """Wrapper module for ONNX export with mean pooling built in."""
    def __init__(self, transformer):
        super().__init__()
        self.transformer = transformer
    
    def forward(self, input_ids, attention_mask):
        outputs = self.transformer(input_ids=input_ids, attention_mask=attention_mask)
        embeddings = mean_pooling(outputs, attention_mask)
        # Normalize embeddings
        embeddings = torch.nn.functional.normalize(embeddings, p=2, dim=1)
        return embeddings

def export_to_onnx(model_name='all-MiniLM-L6-v2', output_dir='assets/models'):
    """Export the sentence-transformers model to ONNX format."""
    print(f"=== Exporting {model_name} to ONNX ===\n")
    
    os.makedirs(output_dir, exist_ok=True)
    
    # Step 1: Load the model
    print("Step 1: Loading sentence-transformers model...")
    model = SentenceTransformer(model_name)
    transformer = model[0].auto_model
    tokenizer = model.tokenizer
    print(f"Model loaded! Hidden size: {transformer.config.hidden_size}")
    
    # Step 2: Save vocabulary
    print("\nStep 2: Saving vocabulary...")
    vocab_path = os.path.join(output_dir, 'vocab.txt')
    tokenizer.save_vocabulary(output_dir)
    print(f"Vocabulary saved to {output_dir}")
    
    # Step 3: Create wrapper and export
    print("\nStep 3: Exporting to ONNX...")
    encoder = SentenceEncoderONNX(transformer)
    encoder.eval()
    
    # Create dummy inputs
    batch_size = 1
    seq_length = 128
    dummy_input_ids = torch.zeros(batch_size, seq_length, dtype=torch.long)
    dummy_attention_mask = torch.ones(batch_size, seq_length, dtype=torch.long)
    
    onnx_path = os.path.join(output_dir, 'sentence_encoder.onnx')
    
    torch.onnx.export(
        encoder,
        (dummy_input_ids, dummy_attention_mask),
        onnx_path,
        input_names=['input_ids', 'attention_mask'],
        output_names=['embeddings'],
        dynamic_axes={
            'input_ids': {0: 'batch_size', 1: 'sequence'},
            'attention_mask': {0: 'batch_size', 1: 'sequence'},
            'embeddings': {0: 'batch_size'}
        },
        opset_version=14,
        do_constant_folding=True
    )
    
    size_mb = os.path.getsize(onnx_path) / (1024 * 1024)
    print(f"Model exported to {onnx_path}")
    print(f"Model size: {size_mb:.2f} MB")
    
    # Step 4: Verify the model
    print("\nStep 4: Verifying ONNX model...")
    import onnxruntime as ort
    
    session = ort.InferenceSession(onnx_path)
    
    # Test with a real sentence
    test_text = "patience during hardship"
    encoded = tokenizer(
        test_text,
        padding='max_length',
        max_length=128,
        truncation=True,
        return_tensors='np'
    )
    
    onnx_output = session.run(
        None,
        {
            'input_ids': encoded['input_ids'].astype(np.int64),
            'attention_mask': encoded['attention_mask'].astype(np.int64)
        }
    )[0]
    
    # Compare with original model
    original_output = model.encode([test_text])
    
    similarity = np.dot(onnx_output[0], original_output[0]) / (
        np.linalg.norm(onnx_output[0]) * np.linalg.norm(original_output[0])
    )
    
    print(f"Test query: '{test_text}'")
    print(f"Output shape: {onnx_output.shape}")
    print(f"Similarity with original: {similarity:.6f}")
    
    if similarity > 0.99:
        print("✅ Verification passed!")
    else:
        print("⚠️ Warning: Output differs from original")
    
    print("\n=== Export Complete! ===")
    print(f"\nFiles created in {output_dir}:")
    print(f"  - sentence_encoder.onnx ({size_mb:.2f} MB)")
    print(f"  - vocab.txt")
    print("\nYou can now use these in your Flutter app with onnxruntime_flutter!")

if __name__ == '__main__':
    export_to_onnx()
