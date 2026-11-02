import app.lekha.keyboard.core.SortedCandidateIndex;
import java.io.*;
import java.nio.charset.StandardCharsets;
import java.nio.channels.FileChannel;
import java.nio.file.*;
import java.util.*;

/** Input is tab-separated category, key, expected candidates. No Android APIs. */
public class IndexBench {
 public static void main(String[] args) throws Exception {
  List<String[]> cases=new ArrayList<>();
  try(BufferedReader r=Files.newBufferedReader(Paths.get(args[1]),StandardCharsets.UTF_8)){String line;while((line=r.readLine())!=null)cases.add(line.split("\\t",-1));}
  Map<String,List<Long>> times=new TreeMap<>();List<String> errors=new ArrayList<>();
  try(FileChannel f=FileChannel.open(Paths.get(args[0]))) {
   SortedCandidateIndex index=new SortedCandidateIndex(f,0,f.size());
   for(int p=0;p<Integer.parseInt(args[2]);p++)for(String[] row:cases){
    long start=System.nanoTime();List<String> actual=index.lookup(row[1],64);long elapsed=System.nanoTime()-start;
    times.computeIfAbsent(row[0], k->new ArrayList<>()).add(elapsed);
    List<String> expected=Arrays.asList(Arrays.copyOfRange(row,2,row.length));if(expected.size()==1&&expected.get(0).isEmpty())expected=Collections.emptyList();
    if(!actual.equals(expected)&&errors.size()<20)errors.add(p+":"+row[1]);
   }
  }
  for(Map.Entry<String,List<Long>> e:times.entrySet()){List<Long> a=e.getValue();Collections.sort(a);int n=a.size();System.out.printf(Locale.ROOT,"%s n=%d median_ms=%.6f p95_ms=%.6f p99_ms=%.6f max_ms=%.6f%n",e.getKey(),n,a.get((n-1)/2)/1e6,a.get((int)Math.ceil(n*.95)-1)/1e6,a.get((int)Math.ceil(n*.99)-1)/1e6,a.get(n-1)/1e6);}
  if(!errors.isEmpty()){System.err.println("MISMATCH "+errors);System.exit(1);}System.out.println("PASS: all results match index-derived expected lists");
 }
}
