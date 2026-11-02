import app.neptype.keyboard.core.SortedCandidateIndex;
import java.nio.channels.FileChannel;
import java.nio.file.Paths;
import java.util.*;
public final class NepTypeIndexPerf {
 public static void main(String[] args) throws Exception {
  try(FileChannel c=FileChannel.open(Paths.get(args[0]))) {
   SortedCandidateIndex idx=new SortedCandidateIndex(c,0,c.size());
   String[] w={"namaste","pani","football","bhaisakeko","sarkar","kathmandu","aaja","mero","swagat","zaxxy"};
   for(int i=0;i<200;i++)idx.lookup(w[i%w.length],4);
   long[] ns=new long[2000];
   for(int i=0;i<ns.length;i++){long start=System.nanoTime();idx.lookup(w[i%w.length],4);ns[i]=System.nanoTime()-start;}
   Arrays.sort(ns);System.out.printf(Locale.ROOT,"p50=%.4f p95=%.4f ms n=%d%n",ns[1000]/1e6,ns[1900]/1e6,ns.length);
  }
 }
}
