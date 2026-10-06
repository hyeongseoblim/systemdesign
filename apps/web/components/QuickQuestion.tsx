export default function QuickQuestion({ question, answer, explanation }: { question: string; answer: string; explanation: string }) {
  return <section id="questions" className="quick-question">
    <div className="study-section-head"><span>STEP 2</span><div><h2>한 가지만 떠올려 보기</h2><p>답을 먼저 떠올린 뒤, 예시 답과 비교해 보세요.</p></div></div>
    <p className="quick-question-prompt">{question}</p>
    <details className="answer-guide">
      <summary>예시 답과 해설 보기</summary>
      <div className="quick-answer"><strong>예시 답</strong><p>{answer}</p><strong>왜 이렇게 답할까요?</strong><p>{explanation}</p><p className="hint">내가 떠올린 답과 어떤 점이 같고 다른지 비교해 보세요.</p></div>
    </details>
  </section>;
}
