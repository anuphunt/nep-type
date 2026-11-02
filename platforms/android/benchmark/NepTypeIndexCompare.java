import app.neptype.keyboard.core.SortedCandidateIndex;
import java.nio.channels.FileChannel;
import java.nio.file.Paths;
import java.util.*;
public final class NepTypeIndexCompare {
 public static void main(String[] args) throws Exception {
  try(FileChannel c=FileChannel.open(Paths.get(args[0])); Scanner in=new Scanner(System.in,"UTF-8")) {
   SortedCandidateIndex idx=new SortedCandidateIndex(c,0,c.size());
   while(in.hasNextLine())System.out.println(String.join("\t",idx.lookup(in.nextLine(),4)));
  }
 }
}
